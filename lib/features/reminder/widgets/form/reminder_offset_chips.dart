import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_form_section.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Quick "schedule from now" chips (+5m, +15m, +30m, +1h).
class ReminderOffsetChips extends StatelessWidget {
  /// Currently applied offset in minutes, or `null` when a manual time is set.
  final int? activeMinutes;

  /// Called with the chosen offset in minutes.
  final ValueChanged<int> onApply;

  const ReminderOffsetChips({
    super.key,
    required this.activeMinutes,
    required this.onApply,
  });

  static const List<({int minutes, String label})> _chips = [
    (minutes: 5, label: '+5m'),
    (minutes: 15, label: '+15m'),
    (minutes: 30, label: '+30m'),
    (minutes: 60, label: '+1h'),
  ];

  @override
  Widget build(BuildContext context) {
    return ReminderFormSection(
      label: 'Quick Offset From Now',
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          for (final chip in _chips)
            DuskGlassPill(
              key: ValueKey<String>('reminder_offset_${chip.minutes}'),
              onTap: () => onApply(chip.minutes),
              tintColor: activeMinutes == chip.minutes
                  ? AppColors.plumAccent
                  : AppColors.textSecondary,
              height: 34.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                chip.label,
                style: TextStyle(
                  color: activeMinutes == chip.minutes
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
