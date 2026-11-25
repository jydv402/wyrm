import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Dusk Glass row displaying a reminder's target time, recurrence, and controls.
class ReminderTile extends StatelessWidget {
  final ReminderItem reminder;
  final DateTime? nextFireAt;
  final DateTime now;
  final bool is24Hour;
  final double titleFontSize;
  final bool compact;
  final bool showDelete;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 14.0 : 18.0),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10.0 : 14.0,
            vertical: compact ? 8.0 : 10.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.well,
            borderRadius: BorderRadius.circular(compact ? 14.0 : 18.0),
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
                    ? _CompactTileBody(
                        timeText: timeText,
                        statusText: statusText,
                        title: displayTitle,
                        isEnabled: reminder.isEnabled,
                        isSnoozed: _isSnoozed,
                      )
                    : _ExpandedTileBody(
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
                _DeleteTileButton(reminderId: reminder.id, onDelete: onDelete!),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTileBody extends StatelessWidget {
  final String timeText;
  final String statusText;
  final String title;
  final bool isEnabled;
  final bool isSnoozed;

  const _CompactTileBody({
    required this.timeText,
    required this.statusText,
    required this.title,
    required this.isEnabled,
    required this.isSnoozed,
  });

  @override
  Widget build(BuildContext context) {
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
                color: isEnabled ? AppColors.textPrimary : AppColors.textMuted,
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
                  color: isEnabled
                      ? (isSnoozed
                            ? AppColors.accentOrange
                            : AppColors.plumAccent)
                      : AppColors.textMuted,
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
            color: isEnabled ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 12.5,
            fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ExpandedTileBody extends StatelessWidget {
  final ReminderItem reminder;
  final String timeText;
  final String statusText;
  final String title;
  final double titleFontSize;
  final bool isSnoozed;

  const _ExpandedTileBody({
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
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
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
                  color: enabled
                      ? (isSnoozed
                            ? AppColors.accentOrange
                            : AppColors.plumAccent)
                      : AppColors.textMuted,
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
                  color: enabled ? AppColors.textPrimary : AppColors.textMuted,
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

class _DeleteTileButton extends StatelessWidget {
  final String reminderId;
  final VoidCallback onDelete;

  const _DeleteTileButton({required this.reminderId, required this.onDelete});

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
