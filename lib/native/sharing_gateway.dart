import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';

/// Platform boundary for Android shared storage access, external file viewing,
/// and SAF document import into the Unified Shared Folder.
abstract interface class SharingGateway {
  /// Whether the app currently holds storage permission (All Files Access on API 30+).
  Future<bool> hasAllFilesAccess();

  /// Opens the system All Files Access screen (or requests legacy storage permission).
  Future<bool> requestAllFilesAccess();

  /// Resolves the platform's default Unified Shared Folder path (`Downloads/Wyrm`).
  Future<String> resolveDefaultRootPath();

  /// Resolves the platform's primary external storage root (`/storage/emulated/0`).
  Future<String> resolveDeviceBrowseRootPath();

  /// Opens [path] using an external viewer app via Android FileProvider.
  Future<bool> openFile(String path, {String? mimeType});

  /// Launches the system file picker and streams the selected file into [targetDir].
  ///
  /// Returns the imported file name, or `null` if the user cancelled.
  Future<String?> pickAndImportFile(String targetDir);
}

/// Live [SharingGateway] backed by the `wyrm_desk/sharing` [MethodChannel].
final class MethodChannelSharingGateway implements SharingGateway {
  /// Creates a [MethodChannelSharingGateway].
  const MethodChannelSharingGateway();

  /// Method channel implemented by `MainActivity.kt`.
  static const MethodChannel channel = MethodChannel('wyrm_desk/sharing');

  @override
  Future<bool> hasAllFilesAccess() async {
    return await _invoke<bool>('hasAllFilesAccess') ?? false;
  }

  @override
  Future<bool> requestAllFilesAccess() async {
    return await _invoke<bool>('requestAllFilesAccess') ?? false;
  }

  @override
  Future<String> resolveDefaultRootPath() async {
    final resolved = await _invoke<String>('getDefaultSharingRoot');
    if (resolved == null || resolved.trim().isEmpty) {
      return AppSettingsConfig.defaultSharingRootPath;
    }
    return resolved.trim();
  }

  @override
  Future<String> resolveDeviceBrowseRootPath() async {
    final resolved = await _invoke<String>('getExternalStorageRoot');
    if (resolved == null || resolved.trim().isEmpty) {
      return AppSettingsConfig.deviceBrowseRootPath;
    }
    return resolved.trim();
  }

  @override
  Future<bool> openFile(String path, {String? mimeType}) async {
    return await _invoke<bool>('openFile', <String, Object?>{
          'path': path,
          'mimeType': mimeType,
        }) ??
        false;
  }

  @override
  Future<String?> pickAndImportFile(String targetDir) {
    return _invoke<String>('pickImportFile', <String, Object?>{
      'targetDir': targetDir,
    });
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint(
          '[SharingGateway] no native handler for "${channel.name}" '
          '($method) - expected on desktop/test targets.',
        );
      }
      return null;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SharingGateway] platform error calling "$method": '
          '${error.message ?? error.code}',
        );
      }
      return null;
    } on UnsupportedError catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SharingGateway] unsupported target calling "$method": $error',
        );
      }
      return null;
    }
  }
}

/// In-memory [SharingGateway] test double for headless and widget tests.
final class FakeSharingGateway implements SharingGateway {
  /// Creates a [FakeSharingGateway].
  FakeSharingGateway({
    this.allFilesAccessGranted = true,
    this.importedFileName,
    this.defaultRootPath = AppSettingsConfig.defaultSharingRootPath,
    this.deviceBrowseRootPath = AppSettingsConfig.deviceBrowseRootPath,
  });

  bool allFilesAccessGranted;
  String? importedFileName;
  String defaultRootPath;
  String deviceBrowseRootPath;
  int requestAccessCount = 0;
  final List<String> openedPaths = <String>[];
  final List<String> importTargetDirs = <String>[];

  @override
  Future<bool> hasAllFilesAccess() async => allFilesAccessGranted;

  @override
  Future<bool> requestAllFilesAccess() async {
    requestAccessCount++;
    return allFilesAccessGranted;
  }

  @override
  Future<String> resolveDefaultRootPath() async => defaultRootPath;

  @override
  Future<String> resolveDeviceBrowseRootPath() async => deviceBrowseRootPath;

  @override
  Future<bool> openFile(String path, {String? mimeType}) async {
    openedPaths.add(path);
    return true;
  }

  @override
  Future<String?> pickAndImportFile(String targetDir) async {
    importTargetDirs.add(targetDir);
    return importedFileName;
  }
}

/// Provider exposing the active [SharingGateway].
final sharingGatewayProvider = Provider<SharingGateway>(
  (ref) => const MethodChannelSharingGateway(),
);
