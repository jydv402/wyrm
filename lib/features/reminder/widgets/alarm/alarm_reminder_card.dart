import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_state.dart';
import 'package:wyrm_desk/features/reminder/reminder_format.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Dusk Glass panel showing the ringing reminder's title, recurrence, and time.
class AlarmReminderCard extends StatelessWidget {
  /// Alarm snapshot being displayed.
  final ActiveAlarmState alarm;

  /// Whether to render the time in 24-hour format.
  final bool is24Hour;

  /// Title font size (larger on the wide layout).
  final double titleFontSize;

  const AlarmReminderCard({
    super.key,
    required this.alarm,
    required this.is24Hour,
    required this.titleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final reminder = alarm.reminder;
    final trimmedTitle = reminder.title.trim();
    final title = trimmedTitle.isEmpty ? 'Reminder' : trimmedTitle;
    final targetTimeLabel = formatReminderClockTime(
      alarm.firedAt,
      is24Hour: is24Hour,
    );
    final isSnoozed = reminder.snoozedUntil != null;

    return DuskGlassPanel(
      tone: AppColors.plum,
      borderRadius: 32.0,
      padding: const EdgeInsets.all(28.0),
      customBorder: Border.all(
        color: AppColors.plumAccent.withValues(alpha: 0.4),
        width: 1.4,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 20.0,
            children: [
              Wrap(
                spacing: 10.0,
                runSpacing: 8.0,
                children: [
                  DuskGlassPill(
                    tintColor: AppColors.plumAccent,
                    height: 32.0,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Text(
                      reminder.recurrence.label,
                      style: const TextStyle(
                        color: AppColors.plumAccent,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (reminder.recurrence == ReminderRecurrence.custom &&
                      reminder.customWeekdays.isNotEmpty)
                    DuskGlassPill(
                      tintColor: AppColors.textSecondary,
                      height: 32.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        formatReminderCustomWeekdays(reminder.customWeekdays),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isSnoozed)
                    const DuskGlassPill(
                      tintColor: AppColors.accentOrange,
                      height: 32.0,
                      padding: EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'Snoozed',
                        style: TextStyle(
                          color: AppColors.accentOrange,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (alarm.isPreview)
                    const DuskGlassPill(
                      tintColor: AppColors.glacierAccent,
                      height: 32.0,
                      padding: EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          color: AppColors.glacierAccent,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(
                    color: AppColors.plumAccent.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10.0,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 22.0,
                      color: AppColors.plumAccent,
                    ),
                    Text(
                      targetTimeLabel,
                      style: const TextStyle(
                        color: AppColors.plumAccent,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
