import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_form_section.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Hour/minute stepper pair with optional AM/PM toggle for the reminder editor.
class ReminderTimeSelector extends StatelessWidget {
  /// Selected hour in 0–23 range.
  final int hour;

  /// Selected minute in 0–59 range.
  final int minute;

  /// Whether to render 24-hour digits and hide the AM/PM pills.
  final bool is24Hour;

  /// Called with the next hour value.
  final ValueChanged<int> onHourChanged;

  /// Called with the next minute value.
  final ValueChanged<int> onMinuteChanged;

  const ReminderTimeSelector({
    super.key,
    required this.hour,
    required this.minute,
    required this.is24Hour,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayHour = is24Hour ? hour : (hour % 12 == 0 ? 12 : hour % 12);
    final isPm = hour >= 12;

    return ReminderFormSection(
      label: 'Target Time',
      child: Wrap(
        spacing: 10.0,
        runSpacing: 10.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _TimeStepperPair(
            label: displayHour.toString().padLeft(2, '0'),
            decKey: const ValueKey<String>('reminder_hour_dec'),
            incKey: const ValueKey<String>('reminder_hour_inc'),
            onDecrement: () => onHourChanged((hour + 23) % 24),
            onIncrement: () => onHourChanged((hour + 1) % 24),
          ),
          const Text(
            ':',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 22.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          _TimeStepperPair(
            label: minute.toString().padLeft(2, '0'),
            decKey: const ValueKey<String>('reminder_min_dec'),
            incKey: const ValueKey<String>('reminder_min_inc'),
            onDecrement: () => onMinuteChanged((minute + 59) % 60),
            onIncrement: () => onMinuteChanged((minute + 1) % 60),
          ),
          if (!is24Hour)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6.0,
              children: [
                _PeriodPill(
                  label: 'AM',
                  key: const ValueKey<String>('reminder_period_am'),
                  isSelected: !isPm,
                  onTap: () {
                    if (isPm) onHourChanged(hour - 12);
                  },
                ),
                _PeriodPill(
                  label: 'PM',
                  key: const ValueKey<String>('reminder_period_pm'),
                  isSelected: isPm,
                  onTap: () {
                    if (!isPm) onHourChanged(hour + 12);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DuskGlassPill(
      onTap: onTap,
      tintColor: isSelected ? AppColors.plumAccent : AppColors.textSecondary,
      height: 36.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimeStepperPair extends StatelessWidget {
  final String label;
  final Key decKey;
  final Key incKey;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _TimeStepperPair({
    required this.label,
    required this.decKey,
    required this.incKey,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6.0,
        children: [
          DuskGlassButton.icon(
            key: decKey,
            onPressed: onDecrement,
            icon: const Icon(
              Icons.remove_rounded,
              size: 16.0,
              color: AppColors.textPrimary,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32.0),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          DuskGlassButton.icon(
            key: incKey,
            onPressed: onIncrement,
            icon: const Icon(
              Icons.add_rounded,
              size: 16.0,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
