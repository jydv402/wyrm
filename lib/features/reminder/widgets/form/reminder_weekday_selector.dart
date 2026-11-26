import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_form_section.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Weekday toggle pills shown for the Custom recurrence.
class ReminderWeekdaySelector extends StatelessWidget {
  /// Currently selected weekdays (1 = Monday … 7 = Sunday).
  final List<int> selectedWeekdays;

  /// Called with the tapped weekday.
  final ValueChanged<int> onToggle;

  const ReminderWeekdaySelector({
    super.key,
    required this.selectedWeekdays,
    required this.onToggle,
  });

  static const List<({int day, String short, String name})> _days = [
    (day: DateTime.monday, short: 'M', name: 'Monday'),
    (day: DateTime.tuesday, short: 'T', name: 'Tuesday'),
    (day: DateTime.wednesday, short: 'W', name: 'Wednesday'),
    (day: DateTime.thursday, short: 'T', name: 'Thursday'),
    (day: DateTime.friday, short: 'F', name: 'Friday'),
    (day: DateTime.saturday, short: 'S', name: 'Saturday'),
    (day: DateTime.sunday, short: 'S', name: 'Sunday'),
  ];

  @override
  Widget build(BuildContext context) {
    return ReminderFormSection(
      label: 'Days of Week',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8.0,
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              for (final day in _days)
                Semantics(
                  label: day.name,
                  selected: selectedWeekdays.contains(day.day),
                  child: DuskGlassPill(
                    key: ValueKey<String>('reminder_weekday_${day.day}'),
                    onTap: () => onToggle(day.day),
                    tintColor: selectedWeekdays.contains(day.day)
                        ? AppColors.plumAccent
                        : AppColors.textSecondary,
                    height: 36.0,
                    padding: const EdgeInsets.symmetric(horizontal: 13.0),
                    child: Text(
                      day.short,
                      style: TextStyle(
                        color: selectedWeekdays.contains(day.day)
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (selectedWeekdays.isEmpty)
            const Text(
              'Select at least one day of the week.',
              style: TextStyle(
                color: AppColors.accentRed,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
