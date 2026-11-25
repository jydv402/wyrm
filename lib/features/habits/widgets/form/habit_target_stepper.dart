import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';

/// Target count stepper and unit input for numeric habits.
class HabitTargetStepper extends StatelessWidget {
  final int targetCount;
  final TextEditingController unitController;
  final ValueChanged<int> onTargetCountChanged;
  final VoidCallback? onChanged;

  const HabitTargetStepper({
    super.key,
    required this.targetCount,
    required this.unitController,
    required this.onTargetCountChanged,
    this.onChanged,
  });

  void _decrement() {
    if (targetCount > 1) {
      onTargetCountChanged(targetCount - 1);
      onChanged?.call();
    }
  }

  void _increment() {
    onTargetCountChanged(targetCount + 1);
    onChanged?.call();
  }

  Widget _buildUnitField() {
    return InAppKeyboardTextField(
      controller: unitController,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Unit (e.g. cups, mins)',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => onChanged?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Daily Target & Unit',
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
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: _decrement,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$targetCount',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.textSecondary,
              ),
              onPressed: _increment,
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildUnitField()),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
