import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';

/// Pure target-schedule resolution output for the reminder editor form and
/// live preview card.
typedef ResolvedReminderSchedule = ({
  DateTime scheduledAt,
  DateTime? nextFireAt,
  bool autoWrappedToTomorrow,
});

/// Resolves [scheduledAt] and [nextFireAt] for the current form inputs using an
/// explicit [now] timestamp.
///
/// For [ReminderRecurrence.once], if [selectedDate] is today (or earlier) and
/// the chosen clock time `hour:minute` is not strictly after [now], the target
/// automatically wraps to tomorrow and sets `autoWrappedToTomorrow = true`.
ResolvedReminderSchedule resolveReminderTarget({
  required DateTime now,
  required int hour,
  required int minute,
  required DateTime selectedDate,
  required ReminderRecurrence recurrence,
  required List<int> customWeekdays,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final pickedDay = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );

  if (recurrence == ReminderRecurrence.once) {
    if (!pickedDay.isAfter(todayStart)) {
      final todayCandidate = DateTime(
        todayStart.year,
        todayStart.month,
        todayStart.day,
        hour,
        minute,
      );
      if (!todayCandidate.isAfter(now)) {
        final tomorrowTarget = DateTime(
          todayStart.year,
          todayStart.month,
          todayStart.day + 1,
          hour,
          minute,
        );
        return (
          scheduledAt: tomorrowTarget,
          nextFireAt: tomorrowTarget,
          autoWrappedToTomorrow: true,
        );
      }
      return (
        scheduledAt: todayCandidate,
        nextFireAt: todayCandidate,
        autoWrappedToTomorrow: false,
      );
    }

    final futureTarget = DateTime(
      pickedDay.year,
      pickedDay.month,
      pickedDay.day,
      hour,
      minute,
    );
    return (
      scheduledAt: futureTarget,
      nextFireAt: futureTarget,
      autoWrappedToTomorrow: false,
    );
  }

  final anchor = DateTime(
    todayStart.year,
    todayStart.month,
    todayStart.day,
    hour,
    minute,
  );
  final previewItem = ReminderItem(
    id: 'preview',
    title: 'Preview',
    scheduledAt: anchor,
    recurrence: recurrence,
    customWeekdays: ReminderItem.normalizeWeekdays(customWeekdays),
    isEnabled: true,
    createdAt: now,
  );
  return (
    scheduledAt: anchor,
    nextFireAt: ReminderScheduler.nextFireAt(previewItem, now: now),
    autoWrappedToTomorrow: false,
  );
}
