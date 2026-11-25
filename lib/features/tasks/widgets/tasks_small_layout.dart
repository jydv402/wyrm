import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/widgets/task_row.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// Compact Small layout: screenshot-matching empty state or glass task checklist.
class TasksSmallLayout extends StatelessWidget {
  final List<TaskItem> tasks;

  const TasksSmallLayout({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const DuskCardEmptyState(
        icon: Icons.check_rounded,
        accentColor: AppColors.rustAccent,
        title: 'All caught up',
        subtitle: 'Tap + to add a task or priority.',
        bottomInset: 80.0,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => TaskRow(task: tasks[index]),
    );
  }
}
