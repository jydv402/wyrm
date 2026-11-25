import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/features/tasks/task_form_content.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Full-screen two-pane virtual keyboard task editor.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key});

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late final TextEditingController _titleController;
  String _selectedPriority = 'normal';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTask() {
    final text = _titleController.text.trim();
    if (text.isNotEmpty) {
      ref
          .read(tasksProvider.notifier)
          .addTask(text, priority: _selectedPriority);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TwoPaneKeyboardScaffold(
      title: 'New Task',
      saveLabel: 'Save Task',
      saveButtonColor: AppColors.rustFill,
      saveTextColor: Colors.white,
      onSave: _saveTask,
      formBuilder: (context, keyboard) {
        return TaskFormContent(
          titleController: _titleController,
          selectedPriority: _selectedPriority,
          onPriorityChanged: (priority) {
            setState(() => _selectedPriority = priority);
          },
          onSubmitted: (_) => _saveTask(),
          onChanged: () => setState(() {}),
        );
      },
      previewBuilder: (context) {
        return TaskPreviewCard(
          title: _titleController.text,
          priority: _selectedPriority,
        );
      },
    );
  }
}
