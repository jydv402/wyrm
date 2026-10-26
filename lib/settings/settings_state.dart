import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/app_database.dart';

/// Immutable configuration model storing user preferences.
class AppSettingsConfig {
  /// Whether the ambient clock formats time in 24-hour mode.
  final bool is24HourFormat;

  /// Font size for text inside task and habit cards (clamped between 11.0 and 22.0 pt).
  final double cardFontSize;

  /// Whether the calendar week starts on Monday (false defaults to Sunday).
  final bool startWeekOnMonday;

  /// Whether to use the classic modal bottom sheet instead of the 2-pane virtual keyboard editor.
  final bool useClassicModalSheet;

  const AppSettingsConfig({
    this.is24HourFormat = false,
    this.cardFontSize = 14.0,
    this.startWeekOnMonday = false,
    this.useClassicModalSheet = false,
  });

  /// Returns a copy of the configuration with specified overrides.
  AppSettingsConfig copyWith({
    bool? is24HourFormat,
    double? cardFontSize,
    bool? startWeekOnMonday,
    bool? useClassicModalSheet,
  }) {
    return AppSettingsConfig(
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
      cardFontSize: cardFontSize ?? this.cardFontSize,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
      useClassicModalSheet: useClassicModalSheet ?? this.useClassicModalSheet,
    );
  }

  /// Serializes the settings configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'is_24_hour_format': is24HourFormat,
      'card_font_size': cardFontSize,
      'start_week_on_monday': startWeekOnMonday,
      'use_classic_modal_sheet': useClassicModalSheet,
    };
  }

  /// Deserializes settings configuration from a JSON map.
  factory AppSettingsConfig.fromJson(Map<String, dynamic> json) {
    return AppSettingsConfig(
      is24HourFormat: json['is_24_hour_format'] as bool? ?? false,
      cardFontSize: (json['card_font_size'] as num?)?.toDouble() ?? 14.0,
      startWeekOnMonday: json['start_week_on_monday'] as bool? ?? false,
      useClassicModalSheet: json['use_classic_modal_sheet'] as bool? ?? false,
    );
  }
}

/// Persists application settings to local JSON storage via AppDatabase.
class AppSettingsStorage {
  /// Loads configuration from unified JSON database storage.
  static Future<AppSettingsConfig> loadSettings() async {
    return await AppDatabase.loadSettings();
  }

  /// Saves the current configuration to unified JSON database storage.
  static Future<void> saveSettings(AppSettingsConfig config) async {
    await AppDatabase.saveSettings(config);
  }
}

/// Manages reactive application settings state and auto-persists updates.
class AppSettingsNotifier extends Notifier<AppSettingsConfig> {
  @override
  AppSettingsConfig build() {
    _initializeFromDisk();
    return const AppSettingsConfig();
  }

  /// Hydrates settings state from local JSON storage.
  Future<void> _initializeFromDisk() async {
    final loaded = await AppSettingsStorage.loadSettings();
    state = loaded;
  }

  /// Toggles between 12-hour and 24-hour clock formats.
  void toggle24HourFormat() {
    set24HourFormat(!state.is24HourFormat);
  }

  /// Sets an explicit value for the 24-hour clock format.
  void set24HourFormat(bool value) {
    final updated = state.copyWith(is24HourFormat: value);
    state = updated;
    AppSettingsStorage.saveSettings(updated);
  }

  /// Sets an explicit font size for card text, clamped between 11.0 and 22.0 pt.
  void setCardFontSize(double size) {
    final clamped = size.clamp(11.0, 22.0);
    final updated = state.copyWith(cardFontSize: clamped);
    state = updated;
    AppSettingsStorage.saveSettings(updated);
  }

  /// Increments card text font size by 1.0 pt up to 22.0 pt.
  void incrementCardFontSize() {
    setCardFontSize(state.cardFontSize + 1.0);
  }

  /// Decrements card text font size by 1.0 pt down to 11.0 pt.
  void decrementCardFontSize() {
    setCardFontSize(state.cardFontSize - 1.0);
  }

  /// Toggles whether calendar weeks start on Monday vs. Sunday.
  void toggleStartWeekOnMonday() {
    setStartWeekOnMonday(!state.startWeekOnMonday);
  }

  /// Sets an explicit value for whether calendar weeks start on Monday.
  void setStartWeekOnMonday(bool value) {
    final updated = state.copyWith(startWeekOnMonday: value);
    state = updated;
    AppSettingsStorage.saveSettings(updated);
  }

  /// Sets whether the app uses the classic modal bottom sheet instead of the 2-pane keyboard editor.
  void setUseClassicModalSheet(bool value) {
    final updated = state.copyWith(useClassicModalSheet: value);
    state = updated;
    AppSettingsStorage.saveSettings(updated);
  }

  /// Toggles between classic modal bottom sheet and the 2-pane keyboard editor.
  void toggleUseClassicModalSheet() {
    setUseClassicModalSheet(!state.useClassicModalSheet);
  }
}

/// Riverpod provider exposing application settings.
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsConfig>(
      AppSettingsNotifier.new,
    );
