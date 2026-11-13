import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';

/// Service coordinating database backup importing and multi-provider state reloading.
class DatabaseService {
  final Ref ref;

  DatabaseService(this.ref);

  /// Reloads all active Riverpod providers from the current database on disk.
  Future<void> reloadAllState() async {
    await Future.wait([
      ref.read(cardLayoutProvider.notifier).reloadFromDisk(),
      ref.read(appSettingsProvider.notifier).reloadFromDisk(),
      ref.read(tasksProvider.notifier).reloadFromDisk(),
      ref.read(calendarProvider.notifier).reloadFromDisk(),
      ref.read(habitsProvider.notifier).reloadFromDisk(),
      ref.read(displayProvider.notifier).reloadFromDisk(),
    ]);
  }

  /// Imports database JSON string, reloads in-memory state, and returns success.
  Future<bool> importAndReloadJson(String jsonString) async {
    final success = await AppDatabase.importDatabaseJson(jsonString);
    if (success) {
      await reloadAllState();
    }
    return success;
  }

  /// Imports from public Downloads, reloads in-memory state, and returns success.
  Future<bool> importFromDownloadsAndReload({String? customPath}) async {
    final success = await AppDatabase.importFromDownloads(customPath: customPath);
    if (success) {
      await reloadAllState();
    }
    return success;
  }
}

/// Provider exposing the centralized database service.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(ref);
});
