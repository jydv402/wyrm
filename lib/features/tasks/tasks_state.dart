import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/repositories/task_repository.dart';

import 'task_model.dart';

/// ViewModel managing reactive task checklist items and routing writes through [TaskRepository].
class TasksNotifier extends Notifier<List<TaskItem>> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);

  @override
  List<TaskItem> build() {
    _initializeFromDisk();
    return const [];
  }

  /// Hydrates tasks from the repository.
  Future<void> _initializeFromDisk() async {
    state = await _repository.loadTasks();
  }

  /// Appends a new task item to the checklist.
  void addTask(String title, {String priority = 'normal'}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final newTask = TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: trimmed,
      priority: priority,
      createdAt: DateTime.now(),
    );

    final updated = [...state, newTask];
    state = updated;
    _repository.saveTasks(updated);
  }

  /// Toggles the completion status of a specific task.
  void toggleTask(String id) {
    final updated = state.map((task) {
      if (task.id == id) {
        return task.copyWith(isCompleted: !task.isCompleted);
      }
      return task;
    }).toList();

    state = updated;
    _repository.saveTasks(updated);
  }

  /// Removes a task permanently from the checklist.
  void deleteTask(String id) {
    final updated = state.where((task) => task.id != id).toList();
    state = updated;
    _repository.saveTasks(updated);
  }

  /// Reloads tasks from disk repository.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing reactive task items.
final tasksProvider = NotifierProvider<TasksNotifier, List<TaskItem>>(
  TasksNotifier.new,
);
