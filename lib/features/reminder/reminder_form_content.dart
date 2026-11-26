import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_target.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_date_selector.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_edit_controls.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_offset_chips.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_recurrence_selector.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_time_selector.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_title_field.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_weekday_selector.dart';

export 'package:wyrm_desk/features/reminder/reminder_target.dart';
export 'package:wyrm_desk/features/reminder/widgets/reminder_preview_card.dart';

/// Reusable Dusk Glass Plum form body for creating and editing reminders.
class ReminderFormContent extends StatelessWidget {
  /// Controller owning the reminder title text.
  final TextEditingController titleController;

  /// Selected hour in 0–23 range.
  final int hour;

  /// Selected minute in 0–59 range.
  final int minute;

  /// Currently selected calendar day for one-time reminders.
  final DateTime selectedDate;

  /// Current wall-clock instant used for auto-wrap and previews.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Selected recurrence rule.
  final ReminderRecurrence recurrence;

  /// Selected custom weekdays when [recurrence] is
  /// [ReminderRecurrence.custom].
  final List<int> customWeekdays;

  /// Whether the reminder schedule is enabled.
  final bool isEnabled;

  /// Whether an existing reminder is being edited.
  final bool isEditing;

  /// Whether to show the required-title validation message.
  final bool showTitleError;

  /// Currently applied quick offset in minutes, if any.
  final int? activeOffsetMinutes;

  /// Called with the next hour value.
  final ValueChanged<int> onHourChanged;

  /// Called with the next minute value.
  final ValueChanged<int> onMinuteChanged;

  /// Called with the newly chosen calendar day.
  final ValueChanged<DateTime> onDateChanged;

  /// Called with a quick offset in minutes.
  final ValueChanged<int> onApplyOffsetMinutes;

  /// Called with the newly chosen recurrence.
  final ValueChanged<ReminderRecurrence> onRecurrenceChanged;

  /// Called with the tapped weekday.
  final ValueChanged<int> onToggleWeekday;

  /// Called when the enabled switch changes.
  final ValueChanged<bool> onEnabledChanged;

  /// Deletes the reminder, or `null` in create mode.
  final VoidCallback? onDelete;

  /// Notifies the editor that a field changed.
  final VoidCallback? onChanged;

  /// Invoked when the keyboard submits the title field.
  final ValueChanged<String>? onSubmitted;

  const ReminderFormContent({
    super.key,
    required this.titleController,
    required this.hour,
    required this.minute,
    required this.selectedDate,
    required this.now,
    required this.is24Hour,
    required this.recurrence,
    required this.customWeekdays,
    required this.isEnabled,
    required this.isEditing,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onDateChanged,
    required this.onApplyOffsetMinutes,
    required this.onRecurrenceChanged,
    required this.onToggleWeekday,
    required this.onEnabledChanged,
    this.showTitleError = false,
    this.activeOffsetMinutes,
    this.onDelete,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = resolveReminderTarget(
      now: now,
      hour: hour,
      minute: minute,
      selectedDate: selectedDate,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16.0,
      children: [
        ReminderTitleField(
          controller: titleController,
          autofocus: !isEditing,
          showError: showTitleError,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
        ReminderOffsetChips(
          activeMinutes: activeOffsetMinutes,
          onApply: onApplyOffsetMinutes,
        ),
        ReminderTimeSelector(
          hour: hour,
          minute: minute,
          is24Hour: is24Hour,
          onHourChanged: onHourChanged,
          onMinuteChanged: onMinuteChanged,
        ),
        if (recurrence == ReminderRecurrence.once)
          ReminderDateSelector(
            now: now,
            scheduledAt: resolved.scheduledAt,
            autoWrappedToTomorrow: resolved.autoWrappedToTomorrow,
            onDateChanged: onDateChanged,
            onChanged: onChanged,
          ),
        ReminderRecurrenceSelector(
          selected: recurrence,
          onChanged: onRecurrenceChanged,
        ),
        if (recurrence == ReminderRecurrence.custom)
          ReminderWeekdaySelector(
            selectedWeekdays: customWeekdays,
            onToggle: onToggleWeekday,
          ),
        if (isEditing)
          ReminderEditControls(
            isEnabled: isEnabled,
            onEnabledChanged: onEnabledChanged,
            onDelete: onDelete,
          ),
      ],
    );
  }
}
