import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Immutable configuration model storing user preferences.
class AppSettingsConfig {
  /// Whether the ambient clock formats time in 24-hour mode.
  final bool is24HourFormat;

  const AppSettingsConfig({
    this.is24HourFormat = false,
  });

  /// Returns a copy of the configuration with specified overrides.
  AppSettingsConfig copyWith({
    bool? is24HourFormat,
  }) {
    return AppSettingsConfig(
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
    );
  }

  /// Serializes the settings configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'is_24_hour_format': is24HourFormat,
    };
  }

  /// Deserializes settings configuration from a JSON map.
  factory AppSettingsConfig.fromJson(Map<String, dynamic> json) {
    return AppSettingsConfig(
      is24HourFormat: json['is_24_hour_format'] as bool? ?? false,
    );
  }
}

/// Persists application settings to local JSON storage.
class AppSettingsStorage {
  /// Resolves the JSON settings file path on the device filesystem.
  static Future<File> getSettingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/app_settings.json');
  }

  /// Loads configuration from local JSON storage, falling back to defaults.
  static Future<AppSettingsConfig> loadSettings() async {
    try {
      final file = await getSettingsFile();
      if (await file.exists()) {
        final rawJson = await file.readAsString();
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        return AppSettingsConfig.fromJson(decoded);
      }
    } catch (_) {
      // Gracefully fall back to defaults if filesystem operations fail.
    }
    return const AppSettingsConfig();
  }

  /// Saves the current configuration to local JSON storage.
  static Future<void> saveSettings(AppSettingsConfig config) async {
    try {
      final file = await getSettingsFile();
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(config.toJson()));
    } catch (_) {
      // Silently ignore disk write failures in constrained environments.
    }
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
}

/// Riverpod provider exposing application settings.
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsConfig>(
  AppSettingsNotifier.new,
);
