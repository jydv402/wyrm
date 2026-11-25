import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';

/// Segmented goal type and frequency mode selector for habits.
class HabitFrequencySelector extends StatelessWidget {
  final HabitType habitType;
  final ValueChanged<HabitType> onTypeChanged;
  final ValueChanged<int>? onTargetCountChanged;
  final int currentTargetCount;
  final VoidCallback? onChanged;

  const HabitFrequencySelector({
    super.key,
    required this.habitType,
    required this.onTypeChanged,
    this.onTargetCountChanged,
    this.currentTargetCount = 1,
    this.onChanged,
  });

  Widget _buildTypeButton({
    required HabitType type,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = habitType == type;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.cardSage
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AppColors.textOnLight
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Goal Type',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildTypeButton(
              type: HabitType.binary,
              label: 'Check-in (Done/Not Done)',
              onTap: () {
                onTypeChanged(HabitType.binary);
                onTargetCountChanged?.call(1);
                onChanged?.call();
              },
            ),
            const SizedBox(width: 8),
            _buildTypeButton(
              type: HabitType.numeric,
              label: 'Target Count (e.g. 8 cups)',
              onTap: () {
                onTypeChanged(HabitType.numeric);
                if (currentTargetCount <= 1) {
                  onTargetCountChanged?.call(8);
                }
                onChanged?.call();
              },
            ),
          ],
        ),
      ],
    );
  }
}
