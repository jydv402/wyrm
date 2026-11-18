/// Immutable model representing the results of an app update check.
class UpdateInfo {
  /// The latest release version tag without 'v' prefix (e.g. '1.0.1').
  final String latestVersion;

  /// The currently installed version of the app (e.g. '1.0.0').
  final String currentVersion;

  /// Whether the latest release is strictly newer than the current installed version.
  final bool isUpdateAvailable;

  /// Direct APK download URL tailored for the device architecture, or universal fallback.
  final String? downloadUrl;

  /// The GitHub release webpage URL (e.g. 'https://github.com/owner/repo/releases/tag/v1.0.1').
  final String releaseUrl;

  /// Markdown-formatted release notes body.
  final String releaseNotes;

  /// Timestamp when the release was published on GitHub.
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.isUpdateAvailable,
    required this.releaseUrl,
    required this.releaseNotes,
    this.downloadUrl,
    this.publishedAt,
  });

  /// The best available URL for the user to download or view the update.
  String get targetUrl => downloadUrl ?? releaseUrl;

  // Override equality and hashCode for value comparison.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateInfo &&
          runtimeType == other.runtimeType &&
          latestVersion == other.latestVersion &&
          currentVersion == other.currentVersion &&
          isUpdateAvailable == other.isUpdateAvailable &&
          downloadUrl == other.downloadUrl &&
          releaseUrl == other.releaseUrl &&
          releaseNotes == other.releaseNotes &&
          publishedAt == other.publishedAt;

  @override
  int get hashCode => Object.hash(
    latestVersion,
    currentVersion,
    isUpdateAvailable,
    downloadUrl,
    releaseUrl,
    releaseNotes,
    publishedAt,
  );
}
