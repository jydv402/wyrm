import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wyrm_desk/features/update_checker/models/update_info.dart';

/// Orchestrates release discovery from GitHub and resolves download links.
class UpdateCheckerService {
  final http.Client _client;
  final String Function()? _archResolver;

  static const String _githubApiBase = 'https://api.github.com/repos';

  UpdateCheckerService({http.Client? client, this._archResolver})
    : _client = client ?? http.Client();

  /// Fetches the latest published release for [githubRepo] from GitHub Releases API.
  Future<Map<String, dynamic>?> fetchLatestRelease(String githubRepo) async {
    try {
      final slug = githubRepo.trim().replaceAll(RegExp(r'^/|/$'), '');
      if (slug.isEmpty) return null;

      final uri = Uri.parse('$_githubApiBase/$slug/releases/latest');
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'WyrmDesk-UpdateChecker',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>?;
      }
    } catch (_) {
      // Return null on network error, timeouts, or JSON decode failure.
    }
    return null;
  }

  /// Compares semantic versions with build numbers.
  ///
  /// Returns `true` if [latest] is strictly newer than [current] (with [currentBuild]).
  /// Supports versions with or without 'v' prefix and build suffixes like `+1`.
  static bool isNewerVersion({
    required String latest,
    required String current,
    String currentBuild = '0',
  }) {
    try {
      final cleanLatest = latest.trim().startsWith('v')
          ? latest.trim().substring(1)
          : latest.trim();
      final cleanCurrent = current.trim().startsWith('v')
          ? current.trim().substring(1)
          : current.trim();

      final latestVerPart = cleanLatest.split('+')[0];
      final currentVerPart = cleanCurrent.split('+')[0];

      final latestParts = latestVerPart
          .split('.')
          .map((s) => int.tryParse(s) ?? 0)
          .toList();
      final currentParts = currentVerPart
          .split('.')
          .map((s) => int.tryParse(s) ?? 0)
          .toList();

      final int latestBuild = cleanLatest.contains('+')
          ? (int.tryParse(cleanLatest.split('+')[1]) ?? 0)
          : 0;
      final int activeBuild = cleanCurrent.contains('+')
          ? (int.tryParse(cleanCurrent.split('+')[1]) ?? 0)
          : (int.tryParse(currentBuild) ?? 0);

      final maxLength = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;

        if (l > c) return true;
        if (l < c) return false;
      }

      return latestBuild > activeBuild;
    } catch (_) {
      return false;
    }
  }

  /// Detects target device CPU architecture ABI (e.g. 'arm64-v8a', 'armeabi-v7a', 'x86_64').
  String getDeviceArchitecture() {
    if (_archResolver != null) return _archResolver();

    try {
      if (Platform.isAndroid) {
        final result = Process.runSync('uname', ['-m']);
        final raw = (result.stdout as String).trim().toLowerCase();
        if (raw.contains('aarch64') || raw.contains('arm64')) {
          return 'arm64-v8a';
        }
        if (raw.contains('arm')) return 'armeabi-v7a';
        if (raw.contains('x86_64') || raw.contains('amd64')) return 'x86_64';
      }
    } catch (_) {}

    return 'arm64-v8a';
  }

  /// Resolves the optimal download APK asset URL from the release metadata.
  ///
  /// Tiered matching:
  /// 1. Exact architecture match in the filename (e.g. 'arm64-v8a').
  /// 2. Universal or release APK ('universal', 'release').
  /// 3. First available .apk asset.
  /// 4. Fallback to `html_url`.
  String? resolveDownloadUrl(Map<String, dynamic> release) {
    final assets = release['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      final arch = getDeviceArchitecture();
      final List<String> apkUrls = [];

      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        final downloadUrl = asset['browser_download_url'] as String?;
        if (name.endsWith('.apk') && downloadUrl != null) {
          if (name.contains(arch)) {
            return downloadUrl;
          }
          apkUrls.add(downloadUrl);
        }
      }

      for (final url in apkUrls) {
        final lower = url.toLowerCase();
        if (lower.contains('universal') || lower.contains('release')) {
          return url;
        }
      }

      if (apkUrls.isNotEmpty) return apkUrls.first;
    }

    return release['html_url'] as String?;
  }

  /// Executes an end-to-end update check against [githubRepo].
  ///
  /// Returns `UpdateInfo` if the release was fetched successfully, or `null` on error.
  Future<UpdateInfo?> check({
    required String githubRepo,
    PackageInfo? packageInfo,
  }) async {
    final release = await fetchLatestRelease(githubRepo);
    if (release == null) return null;

    final info = packageInfo ?? await PackageInfo.fromPlatform();
    final rawTag = (release['tag_name'] as String?) ?? '';
    final cleanLatest = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;

    final bool isAvailable = isNewerVersion(
      latest: rawTag,
      current: info.version,
      currentBuild: info.buildNumber,
    );

    final downloadUrl = resolveDownloadUrl(release);
    final releaseUrl =
        (release['html_url'] as String?) ??
        'https://github.com/$githubRepo/releases/tag/$rawTag';
    final notes =
        (release['body'] as String?)?.trim() ?? 'No release notes provided.';

    DateTime? publishedAt;
    if (release['published_at'] is String) {
      publishedAt = DateTime.tryParse(release['published_at'] as String);
    }

    return UpdateInfo(
      latestVersion: cleanLatest.isNotEmpty ? cleanLatest : rawTag,
      currentVersion: info.version,
      isUpdateAvailable: isAvailable,
      downloadUrl: downloadUrl,
      releaseUrl: releaseUrl,
      releaseNotes: notes,
      publishedAt: publishedAt,
    );
  }
}
