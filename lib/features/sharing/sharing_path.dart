import 'dart:io';

/// Pure path validation, canonicalization, and collision helpers for sharing.
abstract final class SharingPath {
  /// Normalizes a relative path (`/` separated) and rejects traversal attempts.
  ///
  /// Returns `''` for root, or `null` if [rawPath] attempts an escape (`..`,
  /// `.`, absolute root, Windows drive prefix, or null byte).
  static String? normalizeRelativePath(String rawPath) {
    if (rawPath.contains('\x00')) return null;
    final unified = rawPath.replaceAll('\\', '/').trim();
    if (unified.isEmpty || unified == '/') return '';
    if (unified.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(unified)) {
      return null;
    }

    final segments = <String>[];
    for (final rawSegment in unified.split('/')) {
      if (rawSegment.isEmpty) continue;
      if (rawSegment == '.' || rawSegment == '..') return null;
      segments.add(rawSegment);
    }
    return segments.join('/');
  }

  /// Validates and extracts a single safe file or directory base name.
  ///
  /// Strips any directory prefix when callers send a full client path, and
  /// returns `null` when the resulting name is empty, `.`, `..`, or invalid.
  static String? sanitizeEntryName(String rawName) {
    if (rawName.contains('\x00')) return null;
    final normalized = rawName.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return null;
    final baseName = normalized.split('/').last.trim();
    if (baseName.isEmpty || baseName == '.' || baseName == '..') return null;
    if (baseName.contains('/') || baseName.contains('\\')) return null;
    return baseName;
  }

  /// Resolves [relativePath] strictly within [rootPath].
  ///
  /// Returns `null` if [relativePath] is invalid or resolves outside the
  /// canonicalized [rootPath] (including symlink escapes).
  static String? resolveSafePath(String rootPath, String relativePath) {
    final normalizedRel = normalizeRelativePath(relativePath);
    if (normalizedRel == null) return null;

    final canonicalRoot = _canonicalizeRoot(rootPath);
    if (normalizedRel.isEmpty) return canonicalRoot;

    final sep = Platform.pathSeparator;
    final candidate = '$canonicalRoot$sep${normalizedRel.replaceAll('/', sep)}';

    if (!_isSameOrWithin(canonicalRoot, candidate)) return null;

    // Guard against pre-existing symlinks pointing outside the sharing root.
    if (FileSystemEntity.typeSync(candidate, followLinks: false) !=
        FileSystemEntityType.notFound) {
      try {
        final resolved = File(candidate).resolveSymbolicLinksSync();
        if (!_isSameOrWithin(canonicalRoot, resolved)) return null;
      } on FileSystemException {
        // Ignore broken symlinks/platform quirks; lexical check still holds.
      }
    }
    return candidate;
  }

  /// Returns a non-colliding file path inside [dirPath] for [fileName].
  ///
  /// Appends ` (1)`, ` (2)`, etc. before the extension when needed.
  static String uniqueTargetFilePath(String dirPath, String fileName) {
    final sep = Platform.pathSeparator;
    var candidate = '$dirPath$sep$fileName';
    if (FileSystemEntity.typeSync(candidate, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return candidate;
    }

    final dotIndex = fileName.lastIndexOf('.');
    final hasExt = dotIndex > 0;
    final stem = hasExt ? fileName.substring(0, dotIndex) : fileName;
    final ext = hasExt ? fileName.substring(dotIndex) : '';

    var counter = 1;
    while (FileSystemEntity.typeSync(candidate, followLinks: false) !=
        FileSystemEntityType.notFound) {
      candidate = '$dirPath$sep$stem ($counter)$ext';
      counter++;
    }
    return candidate;
  }

  /// Joins a normalized [parent] relative path and [child] entry name.
  static String joinRelativePath(String parent, String child) {
    final cleanParent = parent.replaceAll('\\', '/').trim();
    final cleanChild = child.replaceAll('\\', '/').trim();
    if (cleanParent.isEmpty) return cleanChild;
    if (cleanChild.isEmpty) return cleanParent;
    return '$cleanParent/$cleanChild';
  }

  /// Returns the parent relative path of [relativePath], or `''` at root.
  static String parentRelativePath(String relativePath) {
    final normalized = normalizeRelativePath(relativePath) ?? '';
    final idx = normalized.lastIndexOf('/');
    if (idx <= 0) return '';
    return normalized.substring(0, idx);
  }

  static String _canonicalizeRoot(String rootPath) {
    final dir = Directory(rootPath);
    String path;
    if (dir.existsSync()) {
      try {
        path = dir.resolveSymbolicLinksSync();
      } on FileSystemException {
        path = dir.absolute.path;
      }
    } else {
      path = dir.absolute.path;
    }
    final sep = Platform.pathSeparator;
    while (path.length > 1 && path.endsWith(sep)) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  static bool _isSameOrWithin(String root, String target) {
    final sep = Platform.pathSeparator;
    if (Platform.isWindows) {
      final r = root.toLowerCase();
      final t = target.toLowerCase();
      return t == r || t.startsWith('$r$sep');
    }
    return target == root || target.startsWith('$root$sep');
  }
}
