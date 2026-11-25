import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_color_picker.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_frequency_selector.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_target_stepper.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';

export 'package:wyrm_desk/features/habits/widgets/form/habit_color_picker.dart';
export 'package:wyrm_desk/features/habits/widgets/form/habit_frequency_selector.dart';
export 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';
export 'package:wyrm_desk/features/habits/widgets/form/habit_target_stepper.dart';
export 'package:wyrm_desk/features/habits/widgets/habit_preview_tile.dart';

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
  final String? selectedColorHex;
  final ValueChanged<String>? onColorChanged;

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
    this.selectedColorHex,
    this.onColorChanged,
  });

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 8),
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
      children: [
        _buildTitleInput(),
        const SizedBox(height: 18),
        HabitFrequencySelector(
          habitType: habitType,
          onTypeChanged: onTypeChanged,
          onTargetCountChanged: onTargetCountChanged,
          currentTargetCount: targetCount,
          onChanged: onChanged,
        ),
        const SizedBox(height: 18),
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
        if (selectedColorHex != null && onColorChanged != null) ...[
          const SizedBox(height: 18),
          HabitColorPicker(
            selectedColorHex: selectedColorHex!,
            onColorChanged: onColorChanged!,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}
