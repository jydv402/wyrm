import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';

/// Immutable configuration model storing user preferences.
class AppSettingsConfig {
  /// Whether the ambient clock formats time in 24-hour mode.
  final bool is24HourFormat;

  /// Font size for text inside task and habit cards (clamped between 11.0 and 22.0 pt).
  final double cardFontSize;

  /// Whether the calendar week starts on Monday (false defaults to Sunday).
  final bool startWeekOnMonday;

  const AppSettingsConfig({
    this.is24HourFormat = false,
    this.cardFontSize = 14.0,
    this.startWeekOnMonday = false,
  });

  /// Returns a copy of the configuration with specified overrides.
  AppSettingsConfig copyWith({
    bool? is24HourFormat,
    double? cardFontSize,
    bool? startWeekOnMonday,
  }) {
    return AppSettingsConfig(
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
      cardFontSize: cardFontSize ?? this.cardFontSize,
      startWeekOnMonday: startWeekOnMonday ?? this.startWeekOnMonday,
    );
  }

  /// Serializes the settings configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'is_24_hour_format': is24HourFormat,
      'card_font_size': cardFontSize,
      'start_week_on_monday': startWeekOnMonday,
    };
  }

  /// Deserializes settings configuration from a JSON map.
  factory AppSettingsConfig.fromJson(Map<String, dynamic> json) {
    return AppSettingsConfig(
      is24HourFormat: json['is_24_hour_format'] as bool? ?? false,
      cardFontSize: (json['card_font_size'] as num?)?.toDouble() ?? 14.0,
      startWeekOnMonday: json['start_week_on_monday'] as bool? ?? false,
    );
  }
}

/// Manages reactive application settings state and auto-persists updates.
class AppSettingsNotifier extends Notifier<AppSettingsConfig> {
  @override
  AppSettingsConfig build() {
    _initializeFromDisk();
    return const AppSettingsConfig();
  }

  /// Hydrates settings state from the `settings` database section.
  Future<void> _initializeFromDisk() async {
    final raw = await AppDatabase.readSection('settings');
    state = raw is Map<String, dynamic>
        ? AppSettingsConfig.fromJson(raw)
        : const AppSettingsConfig();
  }

  /// Toggles between 12-hour and 24-hour clock formats.
  void toggle24HourFormat() {
    set24HourFormat(!state.is24HourFormat);
  }

  /// Sets an explicit value for the 24-hour clock format.
  void set24HourFormat(bool value) {
    final updated = state.copyWith(is24HourFormat: value);
    state = updated;
    AppDatabase.writeSection('settings', updated.toJson());
  }

  /// Sets an explicit font size for card text, clamped between 11.0 and 22.0 pt.
  void setCardFontSize(double size) {
    final clamped = size.clamp(11.0, 22.0);
    final updated = state.copyWith(cardFontSize: clamped);
    state = updated;
    AppDatabase.writeSection('settings', updated.toJson());
  }

  /// Toggles whether calendar weeks start on Monday vs. Sunday.
  void toggleStartWeekOnMonday() {
    setStartWeekOnMonday(!state.startWeekOnMonday);
  }

  /// Sets an explicit value for whether calendar weeks start on Monday.
  void setStartWeekOnMonday(bool value) {
    final updated = state.copyWith(startWeekOnMonday: value);
    state = updated;
    AppDatabase.writeSection('settings', updated.toJson());
  }

  /// Reloads application settings from disk.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing application settings.
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsConfig>(
      AppSettingsNotifier.new,
    );
