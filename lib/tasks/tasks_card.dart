import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';
import 'package:wyrm_desk/tasks/tasks_state.dart';
import 'package:wyrm_desk/widgets/bento_box.dart';
import 'package:wyrm_desk/widgets/card_header.dart';

/// Safety orange bento card hosting interactive daily task priorities.
class TasksCard extends ConsumerWidget {
  /// Custom nested content or widget tree overriding default task checklist.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const TasksCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;
    final isFullscreen = currentSize == CardSize.fullscreen;

    final completedCount = tasks.where((t) => t.isCompleted).length;

    return BentoBox(
      color: AppColors.cardOrange,
      borderRadius: 28.0,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12.0 : 16.0,
        vertical: 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.check_box_outlined,
            title: 'Tasks',
            badge: tasks.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$completedCount/${tasks.length}',
                      style: const TextStyle(
                        color: AppColors.textOnLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  )
                : null,
            onAdd: () => _showAddTaskSheet(context, ref),
            onSelectSize: onSelectSize,
            currentSize: currentSize,
            isDarkGlyph: true,
          ),
          const SizedBox(height: 10),

          // Scrollable list of task items or empty state.
          Expanded(
            child: child ??
                (tasks.isEmpty
                    ? _buildEmptyState()
                    : _buildTaskList(
                        context,
                        ref,
                        tasks,
                        isSmall,
                        isFullscreen,
                        settings.cardFontSize,
                      )),
          ),
        ],
      ),
    );
  }

  /// Renders friendly placeholder when no tasks exist.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 32,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            'All caught up',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap + to add a priority',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the uniform scrollable list of tasks with full feature parity across all sizes.
  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    List<TaskItem> tasks,
    bool isSmall,
    bool isFullscreen,
    double fontSize,
  ) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tasks.length,
      separatorBuilder: (_, _) => Divider(
        height: isSmall ? 10 : 12,
        thickness: 0.8,
        color: Colors.black.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isHighPriority = task.priority.toLowerCase() == 'high';

        return InkWell(
          onTap: () => ref.read(tasksProvider.notifier).toggleTask(task.id),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 5.0,
              horizontal: 2.0,
            ),
            child: _buildTaskTile(
              ref,
              task,
              isHighPriority,
              fontSize,
              isSmall: isSmall,
            ),
          ),
        );
      },
    );
  }

  /// Unified task tile layout with centered buttons and overflowing text wrapping to the next line.
  Widget _buildTaskTile(
    WidgetRef ref,
    TaskItem task,
    bool isHighPriority,
    double fontSize, {
    required bool isSmall,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCheckbox(task, isSmall: isSmall),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  softWrap: true,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.isCompleted
                        ? Colors.black38
                        : AppColors.textOnLight,
                    fontWeight:
                        task.isCompleted ? FontWeight.w500 : FontWeight.w600,
                    fontSize: fontSize,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: Colors.black45,
                  ),
                ),
              ),
              if (isHighPriority && !task.isCompleted) ...[
                const SizedBox(width: 6),
                _buildPriorityBadge(),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildDeleteButton(ref, task.id),
      ],
    );
  }

  /// Builds minimalist animated checkbox.
  Widget _buildCheckbox(TaskItem task, {required bool isSmall}) {
    final size = isSmall ? 18.0 : 20.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: task.isCompleted
            ? Colors.black87
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: task.isCompleted
              ? Colors.black87
              : Colors.black.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: task.isCompleted
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.cardOrange,
            )
          : null,
    );
  }

  /// Builds high priority badge.
  Widget _buildPriorityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 1.5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'HIGH',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Builds clear/delete button matching the CardEditButton circular appearance.
  Widget _buildDeleteButton(WidgetRef ref, String taskId) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(tasksProvider.notifier).deleteTask(taskId),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  /// Opens the minimalist modal bottom sheet to input a new task title and priority.
  void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    String selectedPriority = 'normal';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Task',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.accentOrange,
                    decoration: InputDecoration(
                      hintText: 'What needs to be done?',
                      hintStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        ref
                            .read(tasksProvider.notifier)
                            .addTask(val, priority: selectedPriority);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Priority selection chips.
                  Row(
                    children: [
                      const Text(
                        'Priority:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Normal'),
                        selected: selectedPriority == 'normal',
                        selectedColor:
                            AppColors.accentOrange.withValues(alpha: 0.25),
                        backgroundColor: Colors.black.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selectedPriority == 'normal'
                              ? AppColors.accentOrange
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selectedPriority == 'normal'
                              ? AppColors.accentOrange
                              : Colors.transparent,
                        ),
                        onSelected: (_) {
                          setModalState(() => selectedPriority = 'normal');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('High'),
                        selected: selectedPriority == 'high',
                        selectedColor:
                            AppColors.accentOrange.withValues(alpha: 0.25),
                        backgroundColor: Colors.black.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selectedPriority == 'high'
                              ? AppColors.accentOrange
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selectedPriority == 'high'
                              ? AppColors.accentOrange
                              : Colors.transparent,
                        ),
                        onSelected: (_) {
                          setModalState(() => selectedPriority = 'high');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Submit button.
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final text = titleController.text.trim();
                      if (text.isNotEmpty) {
                        ref
                            .read(tasksProvider.notifier)
                            .addTask(text, priority: selectedPriority);
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text(
                      'Add Task',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
