import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';
import 'package:wyrm_desk/features/tasks/widgets/tasks_expanded_layout.dart';
import 'package:wyrm_desk/features/tasks/widgets/tasks_small_layout.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_image_backdrop.dart';

export 'package:wyrm_desk/features/tasks/task_editor_screen.dart';

/// Dusk Glass Tasks card with rust/ember gradient, empty state matching the screenshot,
/// and interactive task checklist with priority pills.
class TasksCard extends ConsumerWidget {
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;

  const TasksCard({
    super.key,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.rust,
      icon: Icons.check_box_outlined,
      title: 'Tasks',
      badge: DuskCountBadge(
        label: tasks.isEmpty
            ? null
            : '${tasks.where((t) => t.isCompleted).length}/${tasks.length}',
        color: AppColors.rustAccent,
      ),
      onAdd: () => _openTaskTwoPaneEditor(context),
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      background: const DuskImageBackdrop(
        assetPath: 'assets/card_bg/task/task_bg.png',
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      child: isSmall
          ? TasksSmallLayout(tasks: tasks)
          : TasksExpandedLayout(tasks: tasks),
    );
  }

  /// Opens the full-screen two-pane virtual keyboard task editor.
  void _openTaskTwoPaneEditor(BuildContext context) {
    context.push(AppRoutes.taskEditor);
  }
}
