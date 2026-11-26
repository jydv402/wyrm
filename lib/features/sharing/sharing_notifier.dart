import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/sharing/sharing_auth.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_path.dart';
import 'package:wyrm_desk/features/sharing/sharing_service.dart';
import 'package:wyrm_desk/features/sharing/sharing_state.dart';
import 'package:wyrm_desk/native/sharing_gateway.dart';
import 'package:wyrm_desk/services/clock_provider.dart';

/// App-scope authenticator for LAN file sharing.
final sharingAuthServiceProvider = Provider<SharingAuthService>((ref) {
  final customPassword = ref.read(appSettingsProvider).sharingCustomPassword;
  return SharingAuthService(initialCustomPassword: customPassword);
});

/// Stateless local filesystem service for `@sharing/`.
final sharingServiceProvider = Provider<SharingService>((ref) {
  return SharingService(clock: ref.watch(clockProvider));
});

/// ViewModel managing storage permission, directory browsing, CRUD actions,
/// and password configuration for `@sharing/`.
class SharingNotifier extends Notifier<SharingState> {
  SharingGateway get _gateway => ref.read(sharingGatewayProvider);
  SharingService get _service => ref.read(sharingServiceProvider);
  SharingAuthService get _auth => ref.read(sharingAuthServiceProvider);

  @override
  SharingState build() {
    final settings = ref.read(appSettingsProvider);
    final auth = ref.read(sharingAuthServiceProvider);
    auth.setCustomPassword(settings.sharingCustomPassword);

    ref.listen<AppSettingsConfig>(appSettingsProvider, (previous, next) {
      if (previous?.sharingCustomPassword != next.sharingCustomPassword) {
        _auth.setCustomPassword(next.sharingCustomPassword);
        state = state.copyWith(
          passwordDisplay: _auth.activePassword,
          isCustomPassword: _auth.isCustomPassword,
          revision: state.revision + 1,
        );
      }

      final nextRoot = _resolveRootPath(next);
      if (nextRoot != state.activeRootPath) {
        state = state.copyWith(
          activeRootPath: nextRoot,
          currentRelativePath: '',
          entries: const <SharedFileEntry>[],
          clearError: true,
        );
        unawaited(refreshPermissionAndDirectory());
      }
    });

    Future<void>.microtask(refreshPermissionAndDirectory);
    return SharingState(
      activeRootPath: _resolveRootPath(settings),
      isLoading: true,
      passwordDisplay: auth.activePassword,
      isCustomPassword: auth.isCustomPassword,
    );
  }

  static String _resolveRootPath(AppSettingsConfig settings) {
    return settings.sharingAllowDeviceBrowse
        ? AppSettingsConfig.deviceBrowseRootPath
        : settings.sharingRootPath;
  }

  /// Re-checks `MANAGE_EXTERNAL_STORAGE` and reloads the current directory.
  Future<void> refreshPermissionAndDirectory({
    bool bumpRevision = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final hasAccess = await _gateway.hasAllFilesAccess();
    if (!ref.mounted) return;

    if (!hasAccess) {
      state = state.copyWith(
        hasPermission: false,
        entries: const <SharedFileEntry>[],
        isLoading: false,
        revision: bumpRevision ? state.revision + 1 : state.revision,
      );
      return;
    }

    final settings = ref.read(appSettingsProvider);
    if (!settings.sharingAllowDeviceBrowse) {
      final ensureResult = await _service.ensureDirectoryExists(
        state.activeRootPath,
      );
      if (!ref.mounted) return;
      if (ensureResult case SharingError<void>(:final failure)) {
        state = state.copyWith(
          hasPermission: true,
          isLoading: false,
          errorMessage: failure.message,
        );
        return;
      }
    }

    await _loadCurrentDirectory(
      hasPermission: true,
      bumpRevision: bumpRevision,
    );
  }

  /// Launches the Android All Files Access settings screen.
  Future<void> requestPermission() async {
    await _gateway.requestAllFilesAccess();
    await refreshPermissionAndDirectory();
  }

  /// Navigates into [relativePath] inside the active sharing root.
  Future<void> navigateTo(String relativePath) async {
    final normalized = SharingPath.normalizeRelativePath(relativePath);
    if (normalized == null) return;
    state = state.copyWith(currentRelativePath: normalized, clearError: true);
    await _loadCurrentDirectory(hasPermission: state.hasPermission);
  }

  /// Navigates one level up toward the sharing root.
  Future<void> navigateUp() async {
    if (state.isAtRoot) return;
    final parent = SharingPath.parentRelativePath(state.currentRelativePath);
    await navigateTo(parent);
  }

  /// Updates directory sort column and direction, then refreshes the listing.
  Future<void> setSort(SharingSortField sortBy, {bool? ascending}) async {
    final nextAscending =
        ascending ?? (state.sortBy == sortBy ? !state.sortAscending : true);
    state = state.copyWith(sortBy: sortBy, sortAscending: nextAscending);
    await _loadCurrentDirectory(hasPermission: state.hasPermission);
  }

  /// Creates a new subdirectory in the active folder.
  Future<bool> createFolder(String folderName) async {
    final result = await _service.createDirectory(
      state.activeRootPath,
      state.currentRelativePath,
      folderName,
    );
    if (!ref.mounted) return false;
    return _handleMutationResult(result);
  }

  /// Renames an entry within its current directory.
  Future<bool> renameEntry(String relativePath, String newName) async {
    final result = await _service.renameEntry(
      state.activeRootPath,
      relativePath,
      newName,
    );
    if (!ref.mounted) return false;
    return _handleMutationResult(result);
  }

  /// Moves [sourceRelativePath] into [targetDirRelativePath].
  Future<bool> moveEntry(
    String sourceRelativePath,
    String targetDirRelativePath,
  ) async {
    final result = await _service.moveEntry(
      state.activeRootPath,
      sourceRelativePath,
      targetDirRelativePath,
    );
    if (!ref.mounted) return false;
    return _handleMutationResult(result);
  }

  /// Permanently deletes a file or folder.
  Future<bool> deleteEntry(String relativePath) async {
    final result = await _service.deleteEntry(
      state.activeRootPath,
      relativePath,
    );
    if (!ref.mounted) return false;
    return _handleMutationResult(result);
  }

  /// Picks a file via Android SAF and copies it into the current folder.
  Future<bool> importFromDevicePicker() async {
    if (!state.hasPermission) return false;
    final targetDir = SharingPath.resolveSafePath(
      state.activeRootPath,
      state.currentRelativePath,
    );
    if (targetDir == null) return false;

    final importedName = await _gateway.pickAndImportFile(targetDir);
    if (!ref.mounted || importedName == null) return false;
    await _loadCurrentDirectory(hasPermission: true, bumpRevision: true);
    return true;
  }

  /// Opens a folder inline or launches a file in an external Android app.
  Future<bool> openEntry(SharedFileEntry entry) async {
    if (entry.isDirectory) {
      await navigateTo(entry.relativePath);
      return true;
    }
    final resolved = SharingPath.resolveSafePath(
      state.activeRootPath,
      entry.relativePath,
    );
    if (resolved == null) return false;
    return _gateway.openFile(resolved, mimeType: entry.mimeType);
  }

  /// Generates a fresh 6-character code, clears any custom password, and revokes
  /// all active Web Remote / QR tokens.
  void regeneratePassword() {
    final nextCode = _auth.regeneratePassword();
    ref.read(appSettingsProvider.notifier).setSharingCustomPassword(null);
    state = state.copyWith(
      passwordDisplay: nextCode,
      isCustomPassword: false,
      revision: state.revision + 1,
    );
  }

  /// Sets a custom password (or clears back to auto-generated when empty/null).
  void setCustomPassword(String? password) {
    final trimmed = password?.trim();
    _auth.setCustomPassword(trimmed);
    ref.read(appSettingsProvider.notifier).setSharingCustomPassword(trimmed);
    state = state.copyWith(
      passwordDisplay: _auth.activePassword,
      isCustomPassword: _auth.isCustomPassword,
      revision: state.revision + 1,
    );
  }

  /// Issues a valid session token for one-tap tablet-generated QR file links.
  String issueShareToken() {
    return _auth.authenticate(_auth.activePassword) ?? '';
  }

  /// Called by [SharingServerSection] after remote HTTP mutations so the
  /// tablet UI refreshes and connected WebSocket clients see the new revision.
  void notifyExternalMutation() {
    unawaited(refreshPermissionAndDirectory(bumpRevision: true));
  }

  Future<bool> _handleMutationResult<T>(SharingResult<T> result) async {
    switch (result) {
      case SharingSuccess<T>():
        await _loadCurrentDirectory(hasPermission: true, bumpRevision: true);
        return true;
      case SharingError<T>(:final failure):
        state = state.copyWith(errorMessage: failure.message);
        return false;
    }
  }

  Future<void> _loadCurrentDirectory({
    required bool hasPermission,
    bool bumpRevision = false,
  }) async {
    if (!hasPermission) {
      state = state.copyWith(hasPermission: false, isLoading: false);
      return;
    }

    var targetPath = state.currentRelativePath;
    var result = await _service.listDirectory(
      state.activeRootPath,
      targetPath,
      sortBy: state.sortBy,
      ascending: state.sortAscending,
    );
    if (!ref.mounted) return;

    // If the currently open subfolder was deleted externally, fall back to root.
    if (result is SharingError<List<SharedFileEntry>> &&
        targetPath.isNotEmpty) {
      targetPath = '';
      result = await _service.listDirectory(
        state.activeRootPath,
        targetPath,
        sortBy: state.sortBy,
        ascending: state.sortAscending,
      );
      if (!ref.mounted) return;
    }

    switch (result) {
      case SharingSuccess<List<SharedFileEntry>>(:final value):
        state = state.copyWith(
          hasPermission: true,
          currentRelativePath: targetPath,
          entries: value,
          isLoading: false,
          clearError: true,
          revision: bumpRevision ? state.revision + 1 : state.revision,
        );
      case SharingError<List<SharedFileEntry>>(:final failure):
        state = state.copyWith(
          hasPermission: true,
          currentRelativePath: targetPath,
          isLoading: false,
          errorMessage: failure.message,
          revision: bumpRevision ? state.revision + 1 : state.revision,
        );
    }
  }
}

/// Provider exposing the live [SharingState] and [SharingNotifier].
final sharingProvider = NotifierProvider<SharingNotifier, SharingState>(
  SharingNotifier.new,
);
