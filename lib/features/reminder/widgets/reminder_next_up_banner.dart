import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

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

/// Plum Dusk Glass banner displaying the next scheduled alarm countdown.
class ReminderNextUpBanner extends StatelessWidget {
  final ReminderItem? reminder;
  final DateTime? fireAt;
  final DateTime now;
  final bool is24Hour;
  final bool hasAnyReminders;
  final bool compact;
  final VoidCallback? onTap;

  const ReminderNextUpBanner({
    super.key,
    required this.reminder,
    required this.fireAt,
    required this.now,
    required this.is24Hour,
    required this.hasAnyReminders,
    this.compact = false,
    this.onTap,
  });

  bool get _isSnoozed {
    final item = reminder;
    final next = fireAt;
    final snooze = item?.snoozedUntil;
    if (item == null || next == null || snooze == null) return false;
    return snooze.isAfter(now) && next.isAtSameMomentAs(snooze);
  }

  @override
  Widget build(BuildContext context) {
    final item = reminder;
    final next = fireAt;

    if (item == null || next == null) {
      return _EmptyNextUpStrip(
        hasAnyReminders: hasAnyReminders,
        compact: compact,
      );
    }

    final timeLabel = formatReminderClockTime(next, is24Hour: is24Hour);
    final countdown = formatReminderCountdown(next, now, isSnoozed: _isSnoozed);
    final title = item.title.trim().isEmpty ? 'Reminder' : item.title.trim();

    final content = compact
        ? _CompactNextUpContent(
            timeLabel: timeLabel,
            countdown: countdown,
            title: title,
          )
        : _HeroNextUpContent(
            timeLabel: timeLabel,
            countdown: countdown,
            title: title,
            recurrenceLabel: item.recurrence.label,
            isSnoozed: _isSnoozed,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 16.0 : 20.0),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12.0 : 16.0,
            vertical: compact ? 10.0 : 14.0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.plumTop.withValues(alpha: 0.9),
                AppColors.plumBottom.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(compact ? 16.0 : 20.0),
            border: Border.all(
              color: AppColors.plumAccent.withValues(alpha: 0.34),
              width: 1.0,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _CompactNextUpContent extends StatelessWidget {
  final String timeLabel;
  final String countdown;
  final String title;

  const _CompactNextUpContent({
    required this.timeLabel,
    required this.countdown,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4.0,
      children: [
        Row(
          spacing: 6.0,
          children: [
            const Icon(
              Icons.alarm_rounded,
              size: 14.0,
              color: AppColors.plumAccent,
            ),
            Text(
              timeLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.0,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Flexible(
              child: DuskGlassPill(
                tintColor: AppColors.plumAccent,
                height: 22.0,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  countdown,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeroNextUpContent extends StatelessWidget {
  final String timeLabel;
  final String countdown;
  final String title;
  final String recurrenceLabel;
  final bool isSnoozed;

  const _HeroNextUpContent({
    required this.timeLabel,
    required this.countdown,
    required this.title,
    required this.recurrenceLabel,
    required this.isSnoozed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        Row(
          spacing: 8.0,
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              size: 15.0,
              color: AppColors.plumAccent,
            ),
            const Text(
              'NEXT UP',
              style: TextStyle(
                color: AppColors.plumAccent,
                fontSize: 11.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            DuskGlassPill(
              tintColor: AppColors.plumAccent,
              height: 24.0,
              padding: const EdgeInsets.symmetric(horizontal: 9.0),
              child: Text(
                recurrenceLabel,
                style: const TextStyle(
                  color: AppColors.plumAccent,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10.0,
          runSpacing: 6.0,
          children: [
            Text(
              timeLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26.0,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            DuskGlassPill(
              tintColor: isSnoozed
                  ? AppColors.accentOrange
                  : AppColors.plumFill,
              height: 26.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Text(
                countdown,
                style: TextStyle(
                  color: isSnoozed
                      ? AppColors.accentOrange
                      : AppColors.plumAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyNextUpStrip extends StatelessWidget {
  final bool hasAnyReminders;
  final bool compact;

  const _EmptyNextUpStrip({
    required this.hasAnyReminders,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12.0 : 14.0,
        vertical: compact ? 8.0 : 12.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(compact ? 14.0 : 18.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 8.0,
        children: [
          const Icon(
            Icons.notifications_paused_rounded,
            size: 16.0,
            color: AppColors.textMuted,
          ),
          Expanded(
            child: Text(
              hasAnyReminders ? 'All reminders paused' : 'No upcoming alarms',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
