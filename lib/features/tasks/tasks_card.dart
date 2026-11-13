import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/tasks/task_form_content.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';
import 'package:wyrm_desk/widgets/dusk_card_header.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Dusk Glass Tasks card with rust/ember gradient, empty state matching the screenshot,
/// and interactive task checklist with priority pills.
class TasksCard extends ConsumerWidget {
  final Widget? child;
  final ValueChanged<CardSize>? onSelectSize;
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
    final isSmall = currentSize == CardSize.small;
    final isFullscreen = currentSize == CardSize.fullscreen;

    final completedCount = tasks.where((t) => t.isCompleted).length;

    final badgeWidget = tasks.isNotEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.rustAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.rustAccent.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Text(
              '$completedCount/${tasks.length}',
              style: const TextStyle(
                color: AppColors.rustAccent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          )
        : null;

    return DuskGlassPanel(
      tone: AppColors.rust,
      borderRadius: 32.0,
      background: const _TasksImageBackdrop(),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuskCardHeader(
            icon: Icons.check_box_outlined,
            title: 'Tasks',
            accentColor: AppColors.rustAccent,
            badge: badgeWidget,
            onAdd: () => _showAddTaskSheet(context, ref),
            addColor: AppColors.rustFill,
            addForegroundColor: Colors.white,
            onSelectSize: onSelectSize,
            currentSize: currentSize,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: isSmall
                ? _buildSmallLayout(context, ref, tasks)
                : _buildExpandedLayout(context, ref, tasks, isFullscreen),
          ),
        ],
      ),
    );
  }

  /// Compact Small layout: screenshot-matching empty state or glass task checklist.
  Widget _buildSmallLayout(
    BuildContext context,
    WidgetRef ref,
    List<TaskItem> tasks,
  ) {
    if (tasks.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskRow(ref, task);
      },
    );
  }

  /// Single Dusk Glass task item row with circular check toggle and priority pill.
  Widget _buildTaskRow(WidgetRef ref, TaskItem task) {
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
          DuskGlassButton.icon(
            onPressed: () =>
                ref.read(tasksProvider.notifier).deleteTask(task.id),
            size: 28,
            icon: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state matching the screenshot: checkmark circle, "All caught up",
  /// and "Tap + to add a task or priority." (no quote).
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Checkmark Circle Glyph
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.rust.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.rust.accent.withValues(alpha: 0.38),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 34,
              color: AppColors.rustAccent,
            ),
          ),

          const SizedBox(height: 16),

          // Title
          const Text(
            'All caught up',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle
          const Text(
            'Tap + to add a task or priority.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Dual-pane split view for Medium & Fullscreen modes.
  Widget _buildExpandedLayout(
    BuildContext context,
    WidgetRef ref,
    List<TaskItem> tasks,
    bool isFullscreen,
  ) {
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Active Tasks List
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Priorities (${activeTasks.length})',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: activeTasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No active priorities.\nTap + to add a task.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: activeTasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildTaskRow(ref, activeTasks[index]),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Vertical divider
        Container(width: 1.0, color: AppColors.lineStrong),

        const SizedBox(width: 16),

        // Right Column: Completed Tasks
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed (${completedTasks.length})',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: completedTasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No completed tasks yet.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: completedTasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildTaskRow(ref, completedTasks[index]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the full-screen two-pane virtual keyboard task editor.
  void _openTaskTwoPaneEditor(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    var selectedPriority = 'normal';

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setEditorState) {
              void saveTask() {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  ref
                      .read(tasksProvider.notifier)
                      .addTask(text, priority: selectedPriority);
                  Navigator.of(context).pop();
                }
              }

              return TwoPaneKeyboardScaffold(
                title: 'New Task',
                saveLabel: 'Save Task',
                saveButtonColor: AppColors.rustFill,
                saveTextColor: Colors.white,
                onSave: saveTask,
                formBuilder: (context, keyboard) {
                  return TaskFormContent(
                    titleController: titleController,
                    selectedPriority: selectedPriority,
                    onPriorityChanged: (priority) =>
                        setEditorState(() => selectedPriority = priority),
                    onSubmitted: (_) => saveTask(),
                    onChanged: () => setEditorState(() {}),
                  );
                },
                previewBuilder: (context) {
                  return TaskPreviewCard(
                    title: titleController.text,
                    priority: selectedPriority,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Opens the 2-pane virtual keyboard editor for adding a new task priority.
  void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
    _openTaskTwoPaneEditor(context, ref);
  }
}

/// Full-bleed image backdrop for the Tasks card using [assets/card_bg/task/task_bg.png].
class _TasksImageBackdrop extends StatelessWidget {
  const _TasksImageBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            // Decode at the larger on-screen dimension so BoxFit.cover
            // stays sharp without decoding the full multi-megabyte asset.
            final longest = constraints.maxWidth >= constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
            return Image.asset(
              'assets/card_bg/task/task_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: (longest * dpr).round(),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.70),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
