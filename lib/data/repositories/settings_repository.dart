import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/data/app_database.dart';

/// Single write path and data persistence repository for application settings.
class SettingsRepository {
  const SettingsRepository();

  /// Loads application settings configuration from the database.
  Future<AppSettingsConfig> loadSettings() async {
    final raw = await AppDatabase.readSection('settings');
    return raw is Map<String, dynamic>
        ? AppSettingsConfig.fromJson(raw)
        : const AppSettingsConfig();
  }

  /// Persists the updated application settings configuration to the database.
  Future<void> saveSettings(AppSettingsConfig config) async {
    await AppDatabase.writeSection('settings', config.toJson());
  }
}

/// Provider exposing the [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SettingsRepository();
});
