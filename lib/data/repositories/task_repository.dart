import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';

/// Single write path and data persistence repository for task items.
class TaskRepository {
  const TaskRepository();

  /// Loads all stored task items from the database.
  Future<List<TaskItem>> loadTasks() async {
    final raw = await AppDatabase.readSection('tasks');
    return raw is List
        ? raw.whereType<Map<String, dynamic>>().map(TaskItem.fromJson).toList()
        : <TaskItem>[];
  }

  /// Persists the updated list of task items to the database.
  Future<void> saveTasks(List<TaskItem> tasks) async {
    await AppDatabase.writeSection(
      'tasks',
      tasks.map((t) => t.toJson()).toList(),
    );
  }
}

/// Provider exposing the [TaskRepository].
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return const TaskRepository();
});
