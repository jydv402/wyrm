import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Single Dusk Glass task item row with circular check toggle and priority pill.
class TaskRow extends ConsumerWidget {
  final TaskItem task;

  const TaskRow({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardFontSize = ref.watch(
      appSettingsProvider.select((s) => s.cardFontSize),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Check Toggle
          InkWell(
            onTap: () => ref.read(tasksProvider.notifier).toggleTask(task.id),
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: task.isCompleted
                    ? AppColors.rust.fill
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: task.isCompleted
                    ? [
                        BoxShadow(
                          color: AppColors.rust.fill.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: task.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          // Task Title
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(tasksProvider.notifier).toggleTask(task.id),
              child: Text(
                task.title,
                softWrap: true,
                style: TextStyle(
                  color: task.isCompleted
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontSize: cardFontSize,
                  fontWeight: task.isCompleted
                      ? FontWeight.w400
                      : FontWeight.w600,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Priority Pill
          if (task.priority.isNotEmpty &&
              task.priority.toLowerCase() != 'normal')
            DuskGlassPill.priority(task.priority),

          const SizedBox(width: 4),

          // Delete Action Button
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.glass,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lineStrong, width: 1.0),
            ),
            child: InkWell(
              onTap: () => ref.read(tasksProvider.notifier).deleteTask(task.id),
              borderRadius: BorderRadius.circular(14),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
