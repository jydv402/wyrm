import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';
import 'package:wyrm_desk/theme/theme.dart';

export 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';

/// Reusable, adaptive form content for creating and editing habits.
class HabitFormContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController unitController;
  final HabitType habitType;
  final int targetCount;
  final String selectedIcon;
  final ValueChanged<HabitType> onTypeChanged;
  final ValueChanged<int> onTargetCountChanged;
  final ValueChanged<String> onIconChanged;
  final VoidCallback? onChanged;
  final bool isEditing;

  const HabitFormContent({
    super.key,
    required this.titleController,
    required this.unitController,
    required this.habitType,
    required this.targetCount,
    required this.selectedIcon,
    required this.onTypeChanged,
    required this.onTargetCountChanged,
    required this.onIconChanged,
    this.onChanged,
    this.isEditing = false,
  });

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8.0,
      children: [
        const Text(
          'Habit Title',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        InAppKeyboardTextField(
          controller: titleController,
          autofocus: !isEditing,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Morning Jog, Drink Water, Read',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => onChanged?.call(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18.0,
      children: [
        _buildTitleInput(),
        HabitFrequencySelector(
          habitType: habitType,
          onTypeChanged: onTypeChanged,
          onTargetCountChanged: onTargetCountChanged,
          currentTargetCount: targetCount,
          onChanged: onChanged,
        ),
        if (habitType == HabitType.numeric)
          HabitTargetStepper(
            targetCount: targetCount,
            unitController: unitController,
            onTargetCountChanged: onTargetCountChanged,
            onChanged: onChanged,
          ),
        HabitIconPicker(
          selectedIcon: selectedIcon,
          onIconChanged: onIconChanged,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Segmented goal type selector: Binary (Check-in) vs Numeric (Target Count).
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
      spacing: 8.0,
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
        Row(
          spacing: 8.0,
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
      spacing: 8.0,
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
      ],
    );
  }
}
