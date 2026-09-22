import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard_text_field.dart';

/// Reusable form content for creating and editing tasks.
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
          cursorColor: AppColors.accentOrange,
          decoration: InputDecoration(
            hintText: 'What needs to be done?',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
            ChoiceChip(
              label: const Text('Normal Priority'),
              selected: selectedPriority == 'normal',
              selectedColor: AppColors.cardOrange,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              labelStyle: TextStyle(
                color: selectedPriority == 'normal'
                    ? AppColors.textOnLight
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selectedPriority == 'normal'
                    ? AppColors.cardOrange
                    : Colors.transparent,
              ),
              onSelected: (_) {
                onPriorityChanged('normal');
                onChanged?.call();
              },
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('High Priority'),
              selected: selectedPriority == 'high',
              selectedColor: AppColors.cardOrange,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              labelStyle: TextStyle(
                color: selectedPriority == 'high'
                    ? AppColors.textOnLight
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selectedPriority == 'high'
                    ? AppColors.cardOrange
                    : Colors.transparent,
              ),
              onSelected: (_) {
                onPriorityChanged('high');
                onChanged?.call();
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// WYSIWYG live preview card for tasks.
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
    final displayTitle =
        title.trim().isEmpty ? 'Write your task description...' : title.trim();
    final isHigh = priority == 'high';

    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
                Icons.task_alt_rounded,
                size: 18,
                color: AppColors.textOnLight,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ACTIVE TASK PREVIEW',
                  style: TextStyle(
                    color: AppColors.textOnLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHigh) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'HIGH',
                    style: TextStyle(
                      color: AppColors.textOnLight,
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
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: AppColors.textOnLight,
                      fontWeight: FontWeight.w700,
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
