import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';
import 'package:wyrm_desk/features/tasks/widgets/priority_option_chip.dart';
import 'package:wyrm_desk/theme/theme.dart';

export 'package:wyrm_desk/features/tasks/widgets/priority_option_chip.dart';
export 'package:wyrm_desk/features/tasks/widgets/task_preview_card.dart';

/// Reusable form content for creating and editing tasks in Dusk Glass style.
class TaskFormContent extends StatelessWidget {
  final TextEditingController titleController;
  final String selectedPriority;
  final ValueChanged<String> onPriorityChanged;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onSubmitted;

  const TaskFormContent({
    super.key,
    required this.titleController,
    required this.selectedPriority,
    required this.onPriorityChanged,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Task Description',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        InAppKeyboardTextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          cursorColor: AppColors.rust.accent,
          decoration: InputDecoration(
            hintText: 'What needs to be done?',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.well,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.rust.accent, width: 1.5),
            ),
          ),
          onChanged: (_) => onChanged?.call(),
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 10), // Originally was 18

        const Text(
          'Priority Level',
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
            PriorityOptionChip(
              value: 'normal',
              label: 'Normal',
              accentColor: AppColors.teal.accent,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
            PriorityOptionChip(
              value: 'low',
              label: 'Low',
              accentColor: AppColors.priorityLow,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
            PriorityOptionChip(
              value: 'medium',
              label: 'Medium',
              accentColor: AppColors.priorityMedium,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
            PriorityOptionChip(
              value: 'high',
              label: 'High',
              accentColor: AppColors.priorityHigh,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
          ],
        ),
      ],
    );
  }
}
