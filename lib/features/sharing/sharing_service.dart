import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:wyrm_desk/features/sharing/sharing_mime.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_path.dart';

/// Stateless filesystem engine backing `@sharing/` reads, writes, and streaming.
///
/// Every path input is validated and canonicalized through [SharingPath] so no
/// caller can escape the configured [rootPath].
class SharingService {
  /// Clock injected for deterministic temp-file timestamps in tests.
  final Clock clock;

  /// Creates a [SharingService].
  const SharingService({this.clock = const Clock()});

  /// Ensures [rootPath] exists on disk.
  Future<SharingResult<void>> ensureDirectoryExists(String rootPath) async {
    try {
      await _createDirectoryIfMissing(Directory(rootPath));
      return const SharingSuccess<void>(null);
    } on FileSystemException catch (error) {
      return SharingError<void>(
        SharingIoError(_formatFsError('Could not initialize folder', rootPath, error)),
      );
    }
  }

  /// Lists entries inside [relativePath] under [rootPath], directories first.
  Future<SharingResult<List<SharedFileEntry>>> listDirectory(
    String rootPath,
    String relativePath, {
    SharingSortField sortBy = SharingSortField.name,
    bool ascending = true,
  }) async {
    final normalizedRel = SharingPath.normalizeRelativePath(relativePath);
    if (normalizedRel == null) {
      return const SharingError<List<SharedFileEntry>>(SharingPathTraversal());
    }
    final resolvedDir = SharingPath.resolveSafePath(rootPath, normalizedRel);
    if (resolvedDir == null) {
      return const SharingError<List<SharedFileEntry>>(SharingPathTraversal());
    }

    final dir = Directory(resolvedDir);
    if (!await dir.exists()) {
      if (normalizedRel.isEmpty) {
        try {
          await _createDirectoryIfMissing(dir);
        } on FileSystemException catch (error) {
          return SharingError<List<SharedFileEntry>>(
            SharingIoError(
              _formatFsError('Could not initialize folder', resolvedDir, error),
            ),
          );
        }
      } else {
        return const SharingError<List<SharedFileEntry>>(
          SharingNotFound('Directory does not exist.'),
        );
      }
    }

    try {
      final entries = <SharedFileEntry>[];
      await for (final entity in dir.list(followLinks: false)) {
        final name = _baseName(entity.path);
        if (name.startsWith('.wyrm_part_')) continue;
        final stat = await entity.stat();
        final isDirectory = stat.type == FileSystemEntityType.directory;
        final rel = SharingPath.joinRelativePath(normalizedRel, name);
        entries.add(
          SharedFileEntry(
            name: name,
            relativePath: rel,
            isDirectory: isDirectory,
            sizeBytes: isDirectory ? 0 : stat.size,
            modifiedAtUtc: stat.modified.toUtc(),
            mimeType: isDirectory
                ? 'inode/directory'
                : SharingMime.inferMimeType(name),
          ),
        );
      }

      entries.sort((a, b) => _compareEntries(a, b, sortBy, ascending));
      return SharingSuccess<List<SharedFileEntry>>(entries);
    } on FileSystemException catch (error) {
      return SharingError<List<SharedFileEntry>>(
        SharingIoError('Could not list directory: ${error.message}'),
      );
    }
  }

  /// Creates a new subdirectory [folderName] inside [parentRelativePath].
  Future<SharingResult<SharedFileEntry>> createDirectory(
    String rootPath,
    String parentRelativePath,
    String folderName,
  ) async {
    final cleanName = SharingPath.sanitizeEntryName(folderName);
    if (cleanName == null) {
      return const SharingError<SharedFileEntry>(SharingInvalidName());
    }
    final targetRel = SharingPath.joinRelativePath(
      parentRelativePath,
      cleanName,
    );
    final resolvedTarget = SharingPath.resolveSafePath(rootPath, targetRel);
    if (resolvedTarget == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }

    final dir = Directory(resolvedTarget);
    if (await dir.exists() || await File(resolvedTarget).exists()) {
      return const SharingError<SharedFileEntry>(SharingAlreadyExists());
    }

    try {
      await dir.create(recursive: true);
      final stat = await dir.stat();
      return SharingSuccess<SharedFileEntry>(
        SharedFileEntry(
          name: cleanName,
          relativePath: targetRel,
          isDirectory: true,
          sizeBytes: 0,
          modifiedAtUtc: stat.modified.toUtc(),
          mimeType: 'inode/directory',
        ),
      );
    } on FileSystemException catch (error) {
      return SharingError<SharedFileEntry>(
        SharingIoError('Could not create folder: ${error.message}'),
      );
    }
  }

  /// Renames a file or folder at [relativePath] to [newName] within the same parent.
  Future<SharingResult<SharedFileEntry>> renameEntry(
    String rootPath,
    String relativePath,
    String newName,
  ) async {
    final normalizedRel = SharingPath.normalizeRelativePath(relativePath);
    if (normalizedRel == null || normalizedRel.isEmpty) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }
    final cleanNewName = SharingPath.sanitizeEntryName(newName);
    if (cleanNewName == null) {
      return const SharingError<SharedFileEntry>(SharingInvalidName());
    }

    final sourcePath = SharingPath.resolveSafePath(rootPath, normalizedRel);
    final parentRel = SharingPath.parentRelativePath(normalizedRel);
    final destRel = SharingPath.joinRelativePath(parentRel, cleanNewName);
    final destPath = SharingPath.resolveSafePath(rootPath, destRel);
    if (sourcePath == null || destPath == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }

    return _relocateEntry(sourcePath, destPath, destRel, cleanNewName);
  }

  /// Moves a file or folder from [sourceRelativePath] into [targetDirRelativePath].
  Future<SharingResult<SharedFileEntry>> moveEntry(
    String rootPath,
    String sourceRelativePath,
    String targetDirRelativePath,
  ) async {
    final normalizedSrc = SharingPath.normalizeRelativePath(sourceRelativePath);
    final normalizedDstDir = SharingPath.normalizeRelativePath(
      targetDirRelativePath,
    );
    if (normalizedSrc == null ||
        normalizedSrc.isEmpty ||
        normalizedDstDir == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }
    // Prevent moving a folder inside itself or its own descendant.
    if (normalizedDstDir == normalizedSrc ||
        normalizedDstDir.startsWith('$normalizedSrc/')) {
      return const SharingError<SharedFileEntry>(
        SharingInvalidName('Cannot move a folder into itself.'),
      );
    }

    final sourcePath = SharingPath.resolveSafePath(rootPath, normalizedSrc);
    final targetDirPath = SharingPath.resolveSafePath(
      rootPath,
      normalizedDstDir,
    );
    if (sourcePath == null || targetDirPath == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }
    if (!await Directory(targetDirPath).exists()) {
      return const SharingError<SharedFileEntry>(
        SharingNotFound('Destination folder does not exist.'),
      );
    }

    final entryName = _baseName(sourcePath);
    final destRel = SharingPath.joinRelativePath(normalizedDstDir, entryName);
    final destPath = SharingPath.resolveSafePath(rootPath, destRel);
    if (destPath == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }

    return _relocateEntry(sourcePath, destPath, destRel, entryName);
  }

  /// Permanently deletes a file or directory (recursively) at [relativePath].
  Future<SharingResult<void>> deleteEntry(
    String rootPath,
    String relativePath,
  ) async {
    final normalizedRel = SharingPath.normalizeRelativePath(relativePath);
    if (normalizedRel == null || normalizedRel.isEmpty) {
      return const SharingError<void>(SharingPathTraversal());
    }
    final resolvedPath = SharingPath.resolveSafePath(rootPath, normalizedRel);
    if (resolvedPath == null) {
      return const SharingError<void>(SharingPathTraversal());
    }

    try {
      final type = FileSystemEntity.typeSync(resolvedPath, followLinks: false);
      switch (type) {
        case FileSystemEntityType.notFound:
          return const SharingError<void>(SharingNotFound());
        case FileSystemEntityType.directory:
          await Directory(resolvedPath).delete(recursive: true);
        case FileSystemEntityType.file:
        case FileSystemEntityType.link:
        case FileSystemEntityType.pipe:
        case FileSystemEntityType.unixDomainSock:
          await File(resolvedPath).delete();
      }
      return const SharingSuccess<void>(null);
    } on FileSystemException catch (error) {
      return SharingError<void>(
        SharingIoError('Could not delete entry: ${error.message}'),
      );
    }
  }

  /// Streams [byteStream] directly to disk inside [relativeDir] without
  /// buffering the full payload in memory, auto-renaming collisions.
  Future<SharingResult<SharedFileEntry>> receiveStreamUpload(
    String rootPath,
    String relativeDir,
    String rawFileName,
    Stream<List<int>> byteStream,
  ) async {
    final normalizedDir = SharingPath.normalizeRelativePath(relativeDir);
    if (normalizedDir == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }
    final cleanName = SharingPath.sanitizeEntryName(rawFileName);
    if (cleanName == null) {
      return const SharingError<SharedFileEntry>(SharingInvalidName());
    }
    final resolvedDir = SharingPath.resolveSafePath(rootPath, normalizedDir);
    if (resolvedDir == null) {
      return const SharingError<SharedFileEntry>(SharingPathTraversal());
    }

    final dir = Directory(resolvedDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final sep = Platform.pathSeparator;
    final tempName = '.wyrm_part_${clock.now().microsecondsSinceEpoch}';
    final tempFile = File('$resolvedDir$sep$tempName');
    IOSink? sink;

    try {
      sink = tempFile.openWrite();
      await sink.addStream(byteStream);
      await sink.flush();
      await sink.close();
      sink = null;

      final finalPath = SharingPath.uniqueTargetFilePath(
        resolvedDir,
        cleanName,
      );
      final finalFile = await tempFile.rename(finalPath);
      final finalName = _baseName(finalFile.path);
      final stat = await finalFile.stat();

      return SharingSuccess<SharedFileEntry>(
        SharedFileEntry(
          name: finalName,
          relativePath: SharingPath.joinRelativePath(normalizedDir, finalName),
          isDirectory: false,
          sizeBytes: stat.size,
          modifiedAtUtc: stat.modified.toUtc(),
          mimeType: SharingMime.inferMimeType(finalName),
        ),
      );
    } catch (error) {
      await sink?.close();
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      return SharingError<SharedFileEntry>(
        SharingIoError('Upload failed: $error'),
      );
    }
  }

  /// Validates and resolves a readable file at [relativePath] for streaming.
  Future<SharingResult<SharingReadTarget>> resolveFileForRead(
    String rootPath,
    String relativePath,
  ) async {
    final normalizedRel = SharingPath.normalizeRelativePath(relativePath);
    if (normalizedRel == null || normalizedRel.isEmpty) {
      return const SharingError<SharingReadTarget>(SharingPathTraversal());
    }
    final resolvedPath = SharingPath.resolveSafePath(rootPath, normalizedRel);
    if (resolvedPath == null) {
      return const SharingError<SharingReadTarget>(SharingPathTraversal());
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      return const SharingError<SharingReadTarget>(SharingNotFound());
    }

    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        return const SharingError<SharingReadTarget>(
          SharingInvalidName('Cannot download a directory.'),
        );
      }
      final name = _baseName(file.path);
      return SharingSuccess<SharingReadTarget>(
        SharingReadTarget(
          file: file,
          sizeBytes: stat.size,
          mimeType: SharingMime.inferMimeType(name),
          name: name,
        ),
      );
    } on FileSystemException catch (error) {
      return SharingError<SharingReadTarget>(
        SharingIoError('Could not read file: ${error.message}'),
      );
    }
  }

  Future<SharingResult<SharedFileEntry>> _relocateEntry(
    String sourcePath,
    String destPath,
    String destRel,
    String destName,
  ) async {
    final type = FileSystemEntity.typeSync(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return const SharingError<SharedFileEntry>(SharingNotFound());
    }
    if (FileSystemEntity.typeSync(destPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return const SharingError<SharedFileEntry>(SharingAlreadyExists());
    }

    try {
      final isDirectory = type == FileSystemEntityType.directory;
      if (isDirectory) {
        await Directory(sourcePath).rename(destPath);
      } else {
        await File(sourcePath).rename(destPath);
      }
      final stat = isDirectory
          ? await Directory(destPath).stat()
          : await File(destPath).stat();
      return SharingSuccess<SharedFileEntry>(
        SharedFileEntry(
          name: destName,
          relativePath: destRel,
          isDirectory: isDirectory,
          sizeBytes: isDirectory ? 0 : stat.size,
          modifiedAtUtc: stat.modified.toUtc(),
          mimeType: isDirectory
              ? 'inode/directory'
              : SharingMime.inferMimeType(destName),
        ),
      );
    } on FileSystemException catch (error) {
      return SharingError<SharedFileEntry>(
        SharingIoError('Could not move or rename entry: ${error.message}'),
      );
    }
  }

  static Future<void> _createDirectoryIfMissing(Directory dir) async {
    if (await dir.exists()) return;
    if (await dir.parent.exists()) {
      await dir.create();
    } else {
      await dir.create(recursive: true);
    }
  }

  static String _formatFsError(
    String prefix,
    String targetPath,
    FileSystemException error,
  ) {
    final os = error.osError;
    final detail = os != null ? '${error.message} (${os.message})' : error.message;
    return '$prefix "$targetPath": $detail';
  }

  static String _baseName(String path) {
    final sep = Platform.pathSeparator;
    final idx = path.lastIndexOf(sep);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  static int _compareEntries(
    SharedFileEntry a,
    SharedFileEntry b,
    SharingSortField sortBy,
    bool ascending,
  ) {
    if (a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    final cmp = switch (sortBy) {
      SharingSortField.name => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      SharingSortField.modified => a.modifiedAtUtc.compareTo(b.modifiedAtUtc),
      SharingSortField.size => a.sizeBytes.compareTo(b.sizeBytes),
    };
    return ascending ? cmp : -cmp;
  }
}
