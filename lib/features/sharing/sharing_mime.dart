/// Pure-Dart MIME inference, inline preview capability, and byte formatting.
abstract final class SharingMime {
  static const Map<String, String> _extensionToMime = <String, String>{
    // Images
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'ico': 'image/x-icon',
    // Audio
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    // Video
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    'mov': 'video/quicktime',
    'avi': 'video/x-msvideo',
    // Documents & Text
    'pdf': 'application/pdf',
    'txt': 'text/plain; charset=utf-8',
    'md': 'text/markdown; charset=utf-8',
    'csv': 'text/csv; charset=utf-8',
    'log': 'text/plain; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'xml': 'application/xml; charset=utf-8',
    'yaml': 'text/yaml; charset=utf-8',
    'yml': 'text/yaml; charset=utf-8',
    'html': 'text/html; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'dart': 'text/plain; charset=utf-8',
    // Archives & Packages
    'zip': 'application/zip',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    '7z': 'application/x-7z-compressed',
    'apk': 'application/vnd.android.package-archive',
  };

  /// Infers a MIME type from [fileNameOrPath], defaulting to octet-stream.
  static String inferMimeType(String fileNameOrPath) {
    final dotIndex = fileNameOrPath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileNameOrPath.length - 1) {
      return 'application/octet-stream';
    }
    final ext = fileNameOrPath.substring(dotIndex + 1).toLowerCase();
    return _extensionToMime[ext] ?? 'application/octet-stream';
  }

  /// Whether a browser can render or play [mimeType] inline in the preview modal.
  static bool isPreviewableMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase();
    return normalized.startsWith('image/') ||
        normalized.startsWith('audio/') ||
        normalized.startsWith('video/') ||
        normalized.startsWith('text/') ||
        normalized.startsWith('application/json') ||
        normalized.startsWith('application/xml') ||
        normalized.startsWith('application/pdf');
  }

  /// Formats [bytes] into a compact human-readable string (e.g. `14.2 MB`).
  static String formatByteSize(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    const units = <String>['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024.0;
    var unitIndex = 0;
    while (value >= 1024.0 && unitIndex < units.length - 1) {
      value /= 1024.0;
      unitIndex++;
    }
    final decimals = value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }
}
