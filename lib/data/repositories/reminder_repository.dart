import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/app_database.dart';

/// Single write path and data persistence repository for reminder items.
class ReminderRepository {
  /// Creates a [ReminderRepository].
  const ReminderRepository();

  /// Loads all stored reminder items from the database.
  Future<List<ReminderItem>> loadReminders() async {
    final raw = await AppDatabase.readSection('reminders');
    return raw is List
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (entry) =>
                    ReminderItem.fromJson(Map<String, dynamic>.from(entry)),
              )
              .toList()
        : <ReminderItem>[];
  }

  /// Loads only enabled reminder items from the database.
  Future<List<ReminderItem>> activeReminders() async {
    final all = await loadReminders();
    return all.where((item) => item.isEnabled).toList();
  }

  /// Persists the updated list of reminder items to the database.
  Future<void> saveReminders(List<ReminderItem> reminders) async {
    await AppDatabase.writeSection(
      'reminders',
      reminders.map((r) => r.toJson()).toList(),
    );
  }
}

/// Provider exposing the [ReminderRepository].
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return const ReminderRepository();
});
