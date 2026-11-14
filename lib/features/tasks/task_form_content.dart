import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';

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
        const SizedBox(height: 8),
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
        const SizedBox(height: 18),

        const Text(
          'Priority Level',
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
            _PriorityOptionChip(
              value: 'normal',
              label: 'Normal',
              accentColor: AppColors.teal.accent,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            _PriorityOptionChip(
              value: 'low',
              label: 'Low',
              accentColor: AppColors.priorityLow,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            _PriorityOptionChip(
              value: 'medium',
              label: 'Medium',
              accentColor: AppColors.priorityMedium,
              selectedValue: selectedPriority,
              onPriorityChanged: onPriorityChanged,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            _PriorityOptionChip(
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

/// One selectable priority pill in the task form.
class _PriorityOptionChip extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;
  final String selectedValue;
  final ValueChanged<String> onPriorityChanged;
  final VoidCallback? onChanged;

  const _PriorityOptionChip({
    required this.value,
    required this.label,
    required this.accentColor,
    required this.selectedValue,
    required this.onPriorityChanged,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          onPriorityChanged(value);
          onChanged?.call();
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.2)
                : AppColors.well,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.line,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live preview card for tasks.
class TaskPreviewCard extends StatelessWidget {
  final String title;
  final String priority;

  const TaskPreviewCard({
    super.key,
    required this.title,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.trim().isEmpty
        ? 'Write your task description...'
        : title.trim();
    final (String, Color)? badge = switch (priority.toLowerCase()) {
      'high' => ('HIGH', AppColors.priorityHigh),
      'medium' => ('MEDIUM', AppColors.priorityMedium),
      'low' => ('LOW', AppColors.priorityLow),
      _ => null,
    };

    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lineStrong, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_box_outlined,
                size: 18,
                color: AppColors.rustAccent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PRIORITY PREVIEW',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badge.$2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: badge.$2.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    badge.$1,
                    style: TextStyle(
                      color: badge.$2,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
