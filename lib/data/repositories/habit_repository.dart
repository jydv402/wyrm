import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';

/// Single write path and data persistence repository for habit items.
class HabitRepository {
  const HabitRepository();

  /// Loads all stored habit items from the database.
  Future<List<HabitItem>> loadHabits() async {
    final raw = await AppDatabase.readSection('habits');
    return raw is List
        ? raw.whereType<Map<String, dynamic>>().map(HabitItem.fromJson).toList()
        : <HabitItem>[];
  }

  /// Persists the updated list of habit items to the database.
  Future<void> saveHabits(List<HabitItem> habits) async {
    await AppDatabase.writeSection(
      'habits',
      habits.map((h) => h.toJson()).toList(),
    );
  }
}

/// Provider exposing the [HabitRepository].
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return const HabitRepository();
});
