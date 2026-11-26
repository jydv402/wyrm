import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';

const Map<int, String> _weekdayAbbr = <int, String>{
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

/// Formats [dateTime] as a clock time respecting [is24Hour] mode.
String formatReminderClockTime(DateTime dateTime, {required bool is24Hour}) {
  final mm = dateTime.minute.toString().padLeft(2, '0');
  if (is24Hour) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  final h12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  return '$h12:$mm $period';
}

/// Formats a concise relative countdown label (e.g. `In 15m`, `Tomorrow`).
String formatReminderCountdown(
  DateTime target,
  DateTime now, {
  bool isSnoozed = false,
}) {
  final diff = target.difference(now);
  final String relative;
  if (diff <= Duration.zero) {
    relative = 'Now';
  } else if (diff.inSeconds < 60) {
    relative = 'In <1m';
  } else {
    final totalMinutes = (diff.inSeconds / 60).ceil();
    final todayStart = DateTime(now.year, now.month, now.day);
    final targetStart = DateTime(target.year, target.month, target.day);
    final dayDiff = targetStart.difference(todayStart).inDays;

    if (dayDiff == 0) {
      if (totalMinutes < 60) {
        relative = 'In ${totalMinutes}m';
      } else {
        final hrs = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        relative = mins == 0 ? 'In ${hrs}h' : 'In ${hrs}h ${mins}m';
      }
    } else if (dayDiff == 1) {
      relative = 'Tomorrow';
    } else {
      relative = 'In ${dayDiff}d';
    }
  }
  return isSnoozed ? 'Snoozed · $relative' : relative;
}

/// Formats the trigger lead time for the editor live preview (`Triggers in ...`).
String formatReminderTriggerEta(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff <= Duration.zero) return 'Triggers now';
  if (diff.inSeconds < 60) return 'Triggers in <1m';

  final totalMinutes = (diff.inSeconds / 60).ceil();
  final days = totalMinutes ~/ (24 * 60);
  final remMinutes = totalMinutes % (24 * 60);
  final hours = remMinutes ~/ 60;
  final minutes = remMinutes % 60;

  if (days > 0) {
    if (hours > 0 && minutes > 0) {
      return 'Triggers in ${days}d ${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return 'Triggers in ${days}d ${hours}h';
    }
    if (minutes > 0) {
      return 'Triggers in ${days}d ${minutes}m';
    }
    return 'Triggers in ${days}d';
  }
  if (hours > 0) {
    return minutes == 0
        ? 'Triggers in ${hours}h'
        : 'Triggers in ${hours}h ${minutes}m';
  }
  return 'Triggers in ${minutes}m';
}

/// Formats a human-readable recurrence summary (e.g. `Mon, Wed, Fri`).
String formatReminderCustomWeekdays(List<int> weekdays) {
  final normalized = ReminderItem.normalizeWeekdays(weekdays);
  if (normalized.isEmpty) return 'Select days';
  if (normalized.length == 7) return 'Every day';
  return normalized.map((day) => _weekdayAbbr[day] ?? '').join(', ');
}

/// Formats a calendar day label relative to [now] (`Today`, `Tomorrow`, or date).
String formatReminderDayLabel(DateTime target, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final targetStart = DateTime(target.year, target.month, target.day);
  final diffDays = targetStart.difference(todayStart).inDays;
  if (diffDays == 0) return 'Today';
  if (diffDays == 1) return 'Tomorrow';
  final month = monthNames[target.month - 1].substring(0, 3);
  return '$month ${target.day}, ${target.year}';
}
