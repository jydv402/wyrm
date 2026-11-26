import 'dart:io';

/// Sort criteria for directory listings in local file sharing.
enum SharingSortField { name, modified, size }

/// Immutable representation of a file or directory inside a shared root.
class SharedFileEntry {
  /// Entry base name (e.g. `notes.txt` or `Photos`).
  final String name;

  /// Relative path from the active sharing root using `/` separators.
  final String relativePath;

  /// Whether this entry is a directory.
  final bool isDirectory;

  /// File size in bytes (`0` for directories).
  final int sizeBytes;

  /// Last modification timestamp in UTC.
  final DateTime modifiedAtUtc;

  /// Inferred MIME type (`inode/directory` for directories).
  final String mimeType;

  /// Creates an immutable [SharedFileEntry].
  const SharedFileEntry({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modifiedAtUtc,
    required this.mimeType,
  });

  /// Serializes this entry for REST API JSON responses.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'relative_path': relativePath,
    'is_directory': isDirectory,
    'size_bytes': sizeBytes,
    'modified_at_utc': modifiedAtUtc.toUtc().toIso8601String(),
    'mime_type': mimeType,
  };

  /// Deserializes an entry from a JSON map.
  factory SharedFileEntry.fromJson(Map<String, dynamic> json) {
    return SharedFileEntry(
      name: json['name'] as String? ?? '',
      relativePath: json['relative_path'] as String? ?? '',
      isDirectory: json['is_directory'] as bool? ?? false,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      modifiedAtUtc:
          DateTime.tryParse(json['modified_at_utc'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedFileEntry &&
          name == other.name &&
          relativePath == other.relativePath &&
          isDirectory == other.isDirectory &&
          sizeBytes == other.sizeBytes &&
          modifiedAtUtc == other.modifiedAtUtc &&
          mimeType == other.mimeType;

  @override
  int get hashCode => Object.hash(
    name,
    relativePath,
    isDirectory,
    sizeBytes,
    modifiedAtUtc,
    mimeType,
  );
}

/// Resolved file descriptor ready for streaming HTTP or native opens.
class SharingReadTarget {
  /// Backing file handle on disk.
  final File file;

  /// Exact byte length of [file].
  final int sizeBytes;

  /// Inferred MIME type.
  final String mimeType;

  /// File base name.
  final String name;

  /// Creates a [SharingReadTarget].
  const SharingReadTarget({
    required this.file,
    required this.sizeBytes,
    required this.mimeType,
    required this.name,
  });
}

/// Typed failure hierarchy for sharing filesystem operations.
sealed class SharingFailure {
  /// Human-readable error summary safe to surface in UI or HTTP errors.
  final String message;

  const SharingFailure(this.message);
}

/// Storage permission (`MANAGE_EXTERNAL_STORAGE`) has not been granted.
final class SharingPermissionDenied extends SharingFailure {
  const SharingPermissionDenied([
    super.message = 'All Files Access permission is required.',
  ]);
}

/// Path attempted to escape the configured sharing root.
final class SharingPathTraversal extends SharingFailure {
  const SharingPathTraversal([
    super.message = 'Access outside the shared root is blocked.',
  ]);
}

/// Target file or directory does not exist.
final class SharingNotFound extends SharingFailure {
  const SharingNotFound([super.message = 'File or folder not found.']);
}

/// Destination entry already exists (e.g. mkdir / rename / move collision).
final class SharingAlreadyExists extends SharingFailure {
  const SharingAlreadyExists([
    super.message = 'An entry with that name already exists.',
  ]);
}

/// Supplied file or folder name is empty or contains illegal characters.
final class SharingInvalidName extends SharingFailure {
  const SharingInvalidName([super.message = 'Invalid file or folder name.']);
}

/// Unexpected local filesystem I/O failure.
final class SharingIoError extends SharingFailure {
  const SharingIoError(super.message);
}

/// Typed outcome wrapper returned across sharing service boundaries.
sealed class SharingResult<T> {
  const SharingResult();
}

/// Successful sharing operation result carrying [value].
final class SharingSuccess<T> extends SharingResult<T> {
  final T value;
  const SharingSuccess(this.value);
}

/// Failed sharing operation result carrying a typed [failure].
final class SharingError<T> extends SharingResult<T> {
  final SharingFailure failure;
  const SharingError(this.failure);
}
