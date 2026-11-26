import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_format.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Right-pane WYSIWYG live preview card for reminder schedules.
class ReminderPreviewCard extends StatelessWidget {
  /// Title typed into the editor (falls back to a placeholder when empty).
  final String title;

  /// Resolved target instant for the current form inputs.
  final DateTime scheduledAt;

  /// Next occurrence produced by the recurrence rule, if any.
  final DateTime? nextFireAt;

  /// Current wall-clock instant used for the relative trigger label.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Selected recurrence shown in the header pill.
  final ReminderRecurrence recurrence;

  /// Selected custom weekdays when [recurrence] is
  /// [ReminderRecurrence.custom].
  final List<int> customWeekdays;

  /// Whether the reminder is enabled (`false` shows `Paused`).
  final bool isEnabled;

  /// Whether the one-time target was auto-wrapped to tomorrow.
  final bool autoWrappedToTomorrow;

  const ReminderPreviewCard({
    super.key,
    required this.title,
    required this.scheduledAt,
    required this.nextFireAt,
    required this.now,
    required this.is24Hour,
    required this.recurrence,
    required this.customWeekdays,
    this.isEnabled = true,
    this.autoWrappedToTomorrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedTitle = title.trim();
    final displayTitle = trimmedTitle.isEmpty
        ? 'Write a reminder title...'
        : trimmedTitle;
    final target = nextFireAt ?? scheduledAt;

    return Container(
      width: 340.0,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.plumTop, AppColors.plumBottom],
        ),
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: AppColors.plumAccent.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.plumGlow.withValues(alpha: 0.35),
            blurRadius: 24.0,
            spreadRadius: -4.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          Row(
            spacing: 8.0,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                size: 18.0,
                color: AppColors.plumAccent,
              ),
              const Expanded(
                child: Text(
                  'REMINDER PREVIEW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              DuskGlassPill(
                tintColor: AppColors.plumAccent,
                height: 24.0,
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  recurrence.label,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: AppColors.plumAccent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6.0,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatReminderClockTime(target, is24Hour: is24Hour),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26.0,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (recurrence == ReminderRecurrence.once) ...[
                      const SizedBox(width: 8.0),
                      DuskGlassPill(
                        tintColor: autoWrappedToTomorrow
                            ? AppColors.accentOrange
                            : AppColors.plumAccent,
                        height: 24.0,
                        padding: const EdgeInsets.symmetric(horizontal: 9.0),
                        child: Text(
                          formatReminderDayLabel(target, now),
                          style: TextStyle(
                            color: autoWrappedToTomorrow
                                ? AppColors.accentOrange
                                : AppColors.plumAccent,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isEnabled ? formatReminderTriggerEta(target, now) : 'Paused',
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (recurrence == ReminderRecurrence.custom)
                  Text(
                    formatReminderCustomWeekdays(customWeekdays),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
