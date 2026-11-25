import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/widgets/task_row.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Dual-pane split view for Medium & Fullscreen modes.
class TasksExpandedLayout extends StatelessWidget {
  final List<TaskItem> tasks;

  const TasksExpandedLayout({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16.0,
      children: [
        // Left Column: Active Tasks List
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12.0,
            children: [
              Text(
                'Active Priorities (${activeTasks.length})',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                            TaskRow(task: activeTasks[index]),
                      ),
              ),
            ],
          ),
        ),

        // Vertical divider
        Container(width: 1.0, color: AppColors.lineStrong),

        // Right Column: Completed Tasks
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12.0,
            children: [
              Text(
                'Completed (${completedTasks.length})',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                            TaskRow(task: completedTasks[index]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
