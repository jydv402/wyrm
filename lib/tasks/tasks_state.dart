import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/app_database.dart';
import 'task_model.dart';

/// Manages reactive task checklist items and persists updates to AppDatabase.
class TasksNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() {
    _initializeFromDisk();
    return const [];
  }

  /// Hydrates stored tasks from the unified JSON database.
  Future<void> _initializeFromDisk() async {
    final loaded = await AppDatabase.loadTasks();
    state = loaded;
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
    AppDatabase.saveTasks(updated);
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
    AppDatabase.saveTasks(updated);
  }

  /// Removes a task permanently from the checklist.
  void deleteTask(String id) {
    final updated = state.where((task) => task.id != id).toList();
    state = updated;
    AppDatabase.saveTasks(updated);
  }

  /// Reloads tasks from disk.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing reactive task items.
final tasksProvider =
    NotifierProvider<TasksNotifier, List<TaskItem>>(TasksNotifier.new);
