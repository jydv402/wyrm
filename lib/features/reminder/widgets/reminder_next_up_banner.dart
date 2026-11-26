import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_format.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_content.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Plum Dusk Glass banner displaying the next scheduled alarm countdown.
class ReminderNextUpBanner extends StatelessWidget {
  /// Reminder with the earliest upcoming occurrence, if any.
  final ReminderItem? reminder;

  /// Fire instant belonging to [reminder], if any.
  final DateTime? fireAt;

  /// Current wall-clock instant used for countdowns.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Whether the store contains any reminders at all.
  final bool hasAnyReminders;

  /// Whether to use the compact (small card) presentation.
  final bool compact;

  /// Opens the reminder editor when tapped.
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
      return EmptyNextUpStrip(
        hasAnyReminders: hasAnyReminders,
        compact: compact,
      );
    }

    final timeLabel = formatReminderClockTime(next, is24Hour: is24Hour);
    final countdown = formatReminderCountdown(next, now, isSnoozed: _isSnoozed);
    final title = item.title.trim().isEmpty ? 'Reminder' : item.title.trim();
    final borderRadius = BorderRadius.circular(compact ? 16.0 : 20.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
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
            borderRadius: borderRadius,
            border: Border.all(
              color: AppColors.plumAccent.withValues(alpha: 0.34),
              width: 1.0,
            ),
          ),
          child: compact
              ? CompactNextUpContent(
                  timeLabel: timeLabel,
                  countdown: countdown,
                  title: title,
                )
              : HeroNextUpContent(
                  timeLabel: timeLabel,
                  countdown: countdown,
                  title: title,
                  recurrenceLabel: item.recurrence.label,
                  isSnoozed: _isSnoozed,
                ),
        ),
      ),
    );
  }
}
