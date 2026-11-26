import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_form_section.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Recurrence picker (Once / Daily / Weekdays / Custom) for the editor form.
class ReminderRecurrenceSelector extends StatelessWidget {
  /// Currently selected recurrence.
  final ReminderRecurrence selected;

  /// Called with the newly chosen recurrence.
  final ValueChanged<ReminderRecurrence> onChanged;

  const ReminderRecurrenceSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ReminderFormSection(
      label: 'Repeat',
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          for (final recurrence in ReminderRecurrence.values)
            DuskGlassPill(
              key: ValueKey<String>('reminder_recurrence_${recurrence.name}'),
              onTap: () => onChanged(recurrence),
              tintColor: selected == recurrence
                  ? AppColors.plumAccent
                  : AppColors.textSecondary,
              height: 34.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                recurrence.label,
                style: TextStyle(
                  color: selected == recurrence
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: selected == recurrence
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
