import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_format.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Single-line tile body for the small card tier.
class CompactReminderTileBody extends StatelessWidget {
  /// Formatted target time.
  final String timeText;

  /// Relative status label (`In 5m`, `Paused`, …).
  final String statusText;

  /// Reminder title.
  final String title;

  /// Whether the reminder is enabled.
  final bool isEnabled;

  /// Whether the reminder is currently snoozed.
  final bool isSnoozed;

  const CompactReminderTileBody({
    super.key,
    required this.timeText,
    required this.statusText,
    required this.title,
    required this.isEnabled,
    required this.isSnoozed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isEnabled ? AppColors.textPrimary : AppColors.textMuted;
    final statusColor = isEnabled
        ? (isSnoozed ? AppColors.accentOrange : AppColors.plumAccent)
        : AppColors.textMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2.0,
      children: [
        Row(
          spacing: 6.0,
          children: [
            Text(
              timeText,
              style: TextStyle(
                color: primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Flexible(
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primary,
            fontSize: 12.5,
            fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Two-column tile body (time/status + title/recurrence) for medium and
/// fullscreen tiers.
class ExpandedReminderTileBody extends StatelessWidget {
  /// Reminder rendered by this row.
  final ReminderItem reminder;

  /// Formatted target time.
  final String timeText;

  /// Relative status label (`In 5m`, `Paused`, …).
  final String statusText;

  /// Reminder title.
  final String title;

  /// Title font size sourced from app settings.
  final double titleFontSize;

  /// Whether the reminder is currently snoozed.
  final bool isSnoozed;

  const ExpandedReminderTileBody({
    super.key,
    required this.reminder,
    required this.timeText,
    required this.statusText,
    required this.title,
    required this.titleFontSize,
    required this.isSnoozed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = reminder.isEnabled;
    final primary = enabled ? AppColors.textPrimary : AppColors.textMuted;
    final statusColor = enabled
        ? (isSnoozed ? AppColors.accentOrange : AppColors.plumAccent)
        : AppColors.textMuted;
    final recurrenceText = reminder.recurrence == ReminderRecurrence.custom
        ? formatReminderCustomWeekdays(reminder.customWeekdays)
        : reminder.recurrence.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12.0,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 74.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2.0,
            children: [
              Text(
                timeText,
                style: TextStyle(
                  color: primary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4.0,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primary,
                  fontSize: titleFontSize,
                  fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: [
                  DuskGlassPill(
                    tintColor: enabled
                        ? AppColors.plumAccent
                        : AppColors.textMuted,
                    height: 22.0,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      recurrenceText,
                      style: TextStyle(
                        color: enabled
                            ? AppColors.plumAccent
                            : AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isSnoozed)
                    const DuskGlassPill(
                      tintColor: AppColors.accentOrange,
                      height: 22.0,
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Snoozed',
                        style: TextStyle(
                          color: AppColors.accentOrange,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular delete affordance rendered at the end of a reminder tile.
class ReminderDeleteButton extends StatelessWidget {
  /// Reminder id used to build the stable test key.
  final String reminderId;

  /// Invoked when tapped.
  final VoidCallback onDelete;

  const ReminderDeleteButton({
    super.key,
    required this.reminderId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30.0,
      height: 30.0,
      decoration: BoxDecoration(
        color: AppColors.glass,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.lineStrong, width: 1.0),
      ),
      child: InkWell(
        key: ValueKey<String>('reminder_delete_$reminderId'),
        onTap: onDelete,
        borderRadius: BorderRadius.circular(15.0),
        child: const Icon(
          Icons.close_rounded,
          size: 15.0,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
