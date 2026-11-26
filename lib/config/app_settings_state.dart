import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/repositories/settings_repository.dart';

/// Immutable configuration model storing user preferences.
class AppSettingsConfig {
  /// Whether the ambient clock formats time in 24-hour mode.
  final bool is24HourFormat;

  /// Font size for text inside task and habit cards (clamped between 11.0 and 22.0 pt).
  final double cardFontSize;

  /// Whether the calendar week starts on Monday (false defaults to Sunday).
  final bool startWeekOnMonday;

  /// Whether automated hourly update checks against GitHub releases are enabled.
  final bool enableAutoUpdateChecks;

  /// GitHub repository slug queried for updates (format: 'owner/repo').
  final String githubRepo;

  /// Minimum clamped text scale factor on tablet displays (default: 0.85).
  final double minTextScaleFactor;

  /// Maximum clamped text scale factor on tablet displays (default: 1.15).
  final double maxTextScaleFactor;

  /// Default Unified Shared Folder path on Android external storage.
  static const String defaultSharingRootPath =
      '/storage/emulated/0/Download/Wyrm';

  /// Full external storage root when device-wide browsing is enabled.
  static const String deviceBrowseRootPath = '/storage/emulated/0';

  /// Configured root directory for local file sharing.
  final String sharingRootPath;

  /// Whether sharing allows browsing all of `/storage/emulated/0` instead of
  /// scoping strictly to [sharingRootPath].
  final bool sharingAllowDeviceBrowse;

  /// Optional user-defined sharing password; when `null`, a 6-char code is
  /// auto-generated on startup.
  final String? sharingCustomPassword;

  const AppSettingsConfig({
    this.is24HourFormat = false,
    this.cardFontSize = 14.0,
    this.startWeekOnMonday = false,
    this.enableAutoUpdateChecks = true,
    this.githubRepo = 'jydv402/wyrm',
    this.minTextScaleFactor = 0.85,
    this.maxTextScaleFactor = 1.15,
    this.sharingRootPath = defaultSharingRootPath,
    this.sharingAllowDeviceBrowse = false,
    this.sharingCustomPassword,
  });

  /// Returns a copy of the configuration with specified overrides.
  AppSettingsConfig copyWith({
    bool? is24HourFormat,
    double? cardFontSize,
    bool? startWeekOnMonday,
    bool? enableAutoUpdateChecks,
    String? githubRepo,
    double? minTextScaleFactor,
    double? maxTextScaleFactor,
    String? sharingRootPath,
    bool? sharingAllowDeviceBrowse,
    String? sharingCustomPassword,
    bool clearSharingCustomPassword = false,
  }) {
    return AppSettingsConfig(
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
      cardFontSize: cardFontSize ?? this.cardFontSize,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
      enableAutoUpdateChecks:
          enableAutoUpdateChecks ?? this.enableAutoUpdateChecks,
      githubRepo: githubRepo ?? this.githubRepo,
      minTextScaleFactor: minTextScaleFactor ?? this.minTextScaleFactor,
      maxTextScaleFactor: maxTextScaleFactor ?? this.maxTextScaleFactor,
      sharingRootPath: sharingRootPath ?? this.sharingRootPath,
      sharingAllowDeviceBrowse:
          sharingAllowDeviceBrowse ?? this.sharingAllowDeviceBrowse,
      sharingCustomPassword: clearSharingCustomPassword
          ? null
          : (sharingCustomPassword ?? this.sharingCustomPassword),
    );
  }

  /// Serializes the settings configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'is_24_hour_format': is24HourFormat,
      'card_font_size': cardFontSize,
      'start_week_on_monday': startWeekOnMonday,
      'enable_auto_update_checks': enableAutoUpdateChecks,
      'github_repo': githubRepo,
      'min_text_scale_factor': minTextScaleFactor,
      'max_text_scale_factor': maxTextScaleFactor,
      'sharing_root_path': sharingRootPath,
      'sharing_allow_device_browse': sharingAllowDeviceBrowse,
      if (sharingCustomPassword != null)
        'sharing_custom_password': sharingCustomPassword,
    };
  }

  /// Deserializes settings configuration from a JSON map.
  factory AppSettingsConfig.fromJson(Map<String, dynamic> json) {
    final rawSharingRoot = json['sharing_root_path'] as String?;
    final rawSharingPassword = json['sharing_custom_password'] as String?;
    return AppSettingsConfig(
      is24HourFormat: json['is_24_hour_format'] as bool? ?? false,
      cardFontSize: (json['card_font_size'] as num?)?.toDouble() ?? 14.0,
      startWeekOnMonday: json['start_week_on_monday'] as bool? ?? false,
      enableAutoUpdateChecks:
          json['enable_auto_update_checks'] as bool? ?? true,
      githubRepo: json['github_repo'] as String? ?? 'jydv402/wyrm',
      minTextScaleFactor:
          (json['min_text_scale_factor'] as num?)?.toDouble() ?? 0.85,
      maxTextScaleFactor:
          (json['max_text_scale_factor'] as num?)?.toDouble() ?? 1.15,
      sharingRootPath:
          (rawSharingRoot != null && rawSharingRoot.trim().isNotEmpty)
          ? rawSharingRoot.trim()
          : defaultSharingRootPath,
      sharingAllowDeviceBrowse:
          json['sharing_allow_device_browse'] as bool? ?? false,
      sharingCustomPassword:
          (rawSharingPassword != null && rawSharingPassword.trim().isNotEmpty)
          ? rawSharingPassword.trim()
          : null,
    );
  }
}

/// Manages reactive application settings state and auto-persists updates via [SettingsRepository].
class AppSettingsNotifier extends Notifier<AppSettingsConfig> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  AppSettingsConfig build() {
    _initializeFromDisk();
    return const AppSettingsConfig();
  }

  /// Hydrates settings state from repository.
  Future<void> _initializeFromDisk() async {
    state = await _repository.loadSettings();
  }

  /// Toggles between 12-hour and 24-hour clock formats.
  void toggle24HourFormat() {
    set24HourFormat(!state.is24HourFormat);
  }

  /// Sets an explicit value for the 24-hour clock format.
  void set24HourFormat(bool value) {
    final updated = state.copyWith(is24HourFormat: value);
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Sets an explicit font size for card text, clamped between 11.0 and 22.0 pt.
  void setCardFontSize(double size) {
    final clamped = size.clamp(11.0, 22.0);
    final updated = state.copyWith(cardFontSize: clamped);
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Sets the min and max text scale factor boundaries.
  void setTextScaleRange({double? min, double? max}) {
    final updated = state.copyWith(
      minTextScaleFactor: min?.clamp(0.5, 1.0),
      maxTextScaleFactor: max?.clamp(1.0, 2.0),
    );
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Toggles whether calendar weeks start on Monday vs. Sunday.
  void toggleStartWeekOnMonday() {
    setStartWeekOnMonday(!state.startWeekOnMonday);
  }

  /// Sets an explicit value for whether calendar weeks start on Monday.
  void setStartWeekOnMonday(bool value) {
    final updated = state.copyWith(startWeekOnMonday: value);
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Toggles automatic hourly update checks.
  void toggleAutoUpdateChecks() {
    setAutoUpdateChecks(!state.enableAutoUpdateChecks);
  }

  /// Sets whether automatic hourly update checks are enabled.
  void setAutoUpdateChecks(bool value) {
    final updated = state.copyWith(enableAutoUpdateChecks: value);
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Sets the GitHub repository slug for update checks.
  void setGithubRepo(String repo) {
    final updated = state.copyWith(githubRepo: repo.trim());
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Sets the Unified Shared Folder root path (falls back to default if empty).
  void setSharingRootPath(String path) {
    final trimmed = path.trim();
    final updated = state.copyWith(
      sharingRootPath: trimmed.isEmpty
          ? AppSettingsConfig.defaultSharingRootPath
          : trimmed,
    );
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Toggles whether sharing allows browsing all of `/storage/emulated/0`.
  void setSharingAllowDeviceBrowse(bool allow) {
    final updated = state.copyWith(sharingAllowDeviceBrowse: allow);
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Sets a custom sharing password, or clears it back to auto-generated when empty/null.
  void setSharingCustomPassword(String? password) {
    final trimmed = password?.trim();
    final updated = (trimmed == null || trimmed.isEmpty)
        ? state.copyWith(clearSharingCustomPassword: true)
        : state.copyWith(sharingCustomPassword: trimmed);
    state = updated;
    _repository.saveSettings(updated);
  }

  /// Reloads application settings from disk repository.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing application settings.
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsConfig>(
      AppSettingsNotifier.new,
    );
