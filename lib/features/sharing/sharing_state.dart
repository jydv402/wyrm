import 'package:flutter/foundation.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';

/// Immutable UI and server coordination state for `@sharing/`.
@immutable
class SharingState {
  /// Whether Android All Files Access (`MANAGE_EXTERNAL_STORAGE`) is granted.
  final bool hasPermission;

  /// Active root directory currently scoped for browsing and transfers.
  final String activeRootPath;

  /// Current relative directory path within [activeRootPath] (`''` = root).
  final String currentRelativePath;

  /// Directory entries in [currentRelativePath].
  final List<SharedFileEntry> entries;

  /// Active sort column.
  final SharingSortField sortBy;

  /// Active sort direction (`true` = ascending).
  final bool sortAscending;

  /// Whether a filesystem refresh or transfer action is currently running.
  final bool isLoading;

  /// Latest user-facing error message, or `null` when healthy.
  final String? errorMessage;

  /// Monotonically increasing counter bumped on every state/file mutation so
  /// connected Web Remote clients know when to re-fetch `GET /api/sharing/files`.
  final int revision;

  /// Active sharing password displayed on the Tablet UI and in Settings.
  final String passwordDisplay;

  /// Whether [passwordDisplay] is user-defined rather than auto-generated.
  final bool isCustomPassword;

  /// Creates an immutable [SharingState].
  const SharingState({
    this.hasPermission = false,
    this.activeRootPath = AppSettingsConfig.defaultSharingRootPath,
    this.currentRelativePath = '',
    this.entries = const <SharedFileEntry>[],
    this.sortBy = SharingSortField.name,
    this.sortAscending = true,
    this.isLoading = false,
    this.errorMessage,
    this.revision = 0,
    this.passwordDisplay = '',
    this.isCustomPassword = false,
  });

  /// Total byte size of files in the current directory listing (derived).
  int get totalBytes {
    var sum = 0;
    for (final entry in entries) {
      if (!entry.isDirectory) sum += entry.sizeBytes;
    }
    return sum;
  }

  /// Number of files (excluding folders) in the current listing (derived).
  int get fileCount => entries.where((e) => !e.isDirectory).length;

  /// Number of folders in the current listing (derived).
  int get folderCount => entries.where((e) => e.isDirectory).length;

  /// Whether the browser is currently at the root directory.
  bool get isAtRoot => currentRelativePath.isEmpty;

  /// Returns a copy of this state with specified overrides.
  SharingState copyWith({
    bool? hasPermission,
    String? activeRootPath,
    String? currentRelativePath,
    List<SharedFileEntry>? entries,
    SharingSortField? sortBy,
    bool? sortAscending,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    int? revision,
    String? passwordDisplay,
    bool? isCustomPassword,
  }) {
    return SharingState(
      hasPermission: hasPermission ?? this.hasPermission,
      activeRootPath: activeRootPath ?? this.activeRootPath,
      currentRelativePath: currentRelativePath ?? this.currentRelativePath,
      entries: entries ?? this.entries,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      revision: revision ?? this.revision,
      passwordDisplay: passwordDisplay ?? this.passwordDisplay,
      isCustomPassword: isCustomPassword ?? this.isCustomPassword,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharingState &&
          hasPermission == other.hasPermission &&
          activeRootPath == other.activeRootPath &&
          currentRelativePath == other.currentRelativePath &&
          listEquals(entries, other.entries) &&
          sortBy == other.sortBy &&
          sortAscending == other.sortAscending &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage &&
          revision == other.revision &&
          passwordDisplay == other.passwordDisplay &&
          isCustomPassword == other.isCustomPassword;

  @override
  int get hashCode => Object.hash(
    hasPermission,
    activeRootPath,
    currentRelativePath,
    Object.hashAll(entries),
    sortBy,
    sortAscending,
    isLoading,
    errorMessage,
    revision,
    passwordDisplay,
    isCustomPassword,
  );
}
