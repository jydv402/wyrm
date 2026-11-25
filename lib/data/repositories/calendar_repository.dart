import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/features/calendar/calendar_model.dart';

/// Single write path and data persistence repository for calendar milestones.
class CalendarRepository {
  const CalendarRepository();

  /// Loads all stored calendar milestones from the database.
  Future<List<CalendarMilestone>> loadMilestones() async {
    final raw = await AppDatabase.readSection('calendar');
    return raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(CalendarMilestone.fromJson)
              .toList()
        : <CalendarMilestone>[];
  }

  /// Persists the updated list of calendar milestones to the database.
  Future<void> saveMilestones(List<CalendarMilestone> milestones) async {
    await AppDatabase.writeSection(
      'calendar',
      milestones.map((m) => m.toJson()).toList(),
    );
  }
}

/// Provider exposing the [CalendarRepository].
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return const CalendarRepository();
});
