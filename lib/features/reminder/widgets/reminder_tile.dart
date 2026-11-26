import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_format.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_tile_bodies.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Dusk Glass row displaying a reminder's target time, recurrence, and controls.
class ReminderTile extends StatelessWidget {
  /// Reminder rendered by this row.
  final ReminderItem reminder;

  /// Next occurrence for [reminder], if any.
  final DateTime? nextFireAt;

  /// Current wall-clock instant used for countdowns.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Title font size sourced from app settings.
  final double titleFontSize;

  /// Whether to use the compact (small card) row layout.
  final bool compact;

  /// Whether to expose the delete button.
  final bool showDelete;

  /// Toggles the reminder's enabled state.
  final ValueChanged<bool>? onToggle;

  /// Opens the editor for this reminder.
  final VoidCallback? onTap;

  /// Deletes this reminder.
  final VoidCallback? onDelete;

  const ReminderTile({
    super.key,
    required this.reminder,
    required this.nextFireAt,
    required this.now,
    required this.is24Hour,
    this.titleFontSize = 14.0,
    this.compact = false,
    this.showDelete = false,
    this.onToggle,
    this.onTap,
    this.onDelete,
  });

  bool get _isSnoozed {
    final snooze = reminder.snoozedUntil;
    if (!reminder.isEnabled || snooze == null) return false;
    return snooze.isAfter(now);
  }

  String _statusLabel() {
    if (!reminder.isEnabled) {
      if (reminder.recurrence == ReminderRecurrence.once &&
          reminder.lastTriggeredAt != null) {
        return 'Done';
      }
      return 'Paused';
    }
    final next = nextFireAt;
    if (next == null) return 'Scheduled';
    return formatReminderCountdown(next, now, isSnoozed: _isSnoozed);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTarget = nextFireAt ?? reminder.scheduledAt;
    final timeText = formatReminderClockTime(
      effectiveTarget,
      is24Hour: is24Hour,
    );
    final statusText = _statusLabel();
    final displayTitle = reminder.title.trim().isEmpty
        ? 'Reminder'
        : reminder.title.trim();
    final borderRadius = BorderRadius.circular(compact ? 14.0 : 18.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10.0 : 14.0,
            vertical: compact ? 8.0 : 10.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.well,
            borderRadius: borderRadius,
            border: Border.all(
              color: _isSnoozed
                  ? AppColors.plumAccent.withValues(alpha: 0.4)
                  : AppColors.line,
              width: 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: compact ? 8.0 : 12.0,
            children: [
              Expanded(
                child: compact
                    ? CompactReminderTileBody(
                        timeText: timeText,
                        statusText: statusText,
                        title: displayTitle,
                        isEnabled: reminder.isEnabled,
                        isSnoozed: _isSnoozed,
                      )
                    : ExpandedReminderTileBody(
                        reminder: reminder,
                        timeText: timeText,
                        statusText: statusText,
                        title: displayTitle,
                        titleFontSize: titleFontSize,
                        isSnoozed: _isSnoozed,
                      ),
              ),
              Switch.adaptive(
                key: ValueKey<String>('reminder_toggle_${reminder.id}'),
                value: reminder.isEnabled,
                activeThumbColor: AppColors.plumAccent,
                activeTrackColor: AppColors.plumFill.withValues(alpha: 0.4),
                inactiveThumbColor: AppColors.textSecondary,
                inactiveTrackColor: AppColors.well,
                onChanged: onToggle,
              ),
              if (showDelete && onDelete != null)
                ReminderDeleteButton(
                  reminderId: reminder.id,
                  onDelete: onDelete!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
