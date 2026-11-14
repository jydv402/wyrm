import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Tasks feature's web remote surface: task list REST routes, the
/// create/toggle/delete WebSocket commands, and the `tasks` snapshot slice.
class TasksServerSection implements ServerSection {
  final List<TaskItem> Function() getTasks;
  final void Function(String title, String priority) onAddTask;
  final void Function(String id) onToggleTask;
  final void Function(String id) onDeleteTask;

  TasksServerSection({
    required this.getTasks,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  /// Whitelisted task priority values accepted from the web remote.
  static const Set<String> _taskPriorities = {
    'normal',
    'medium',
    'high',
    'low',
  };

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.get('/api/tasks', (Request request) {
      return jsonResponse(getTasks().map((t) => t.toJson()).toList());
    });
    router.post('/api/tasks', (Request request) async {
      try {
        final data = await readJsonBody(request);
        final title = (data['title'] ?? data['text']) as String?;
        final priority = data['priority'] as String?;
        if (_executeCreateTask(title, priority)) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid task payload');
    });
    router.post('/api/tasks/toggle', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeToggleTask(data['id'])) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid toggle task payload');
    });
    router.post('/api/tasks/delete', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeDeleteTask(data['id'])) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid delete task payload');
    });
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    switch (data['type'] as String?) {
      case 'create_task':
        return _executeCreateTask(
          data['title'] as String?,
          data['priority'] as String?,
        );
      case 'toggle_task':
        return _executeToggleTask(data['id']);
      case 'delete_task':
        return _executeDeleteTask(data['id']);
      default:
        return false;
    }
  }

  @override
  Map<String, dynamic>? snapshot() {
    return {'tasks': getTasks().map((t) => t.toJson()).toList()};
  }

  /// Validates and triggers task creation.
  ///
  /// An unrecognized or missing [priority] falls back to 'normal' so unknown
  /// remote values never persist into the task model.
  bool _executeCreateTask(String? title, String? priority) {
    if (title != null && title.trim().isNotEmpty) {
      final candidate = (priority ?? 'normal').trim().toLowerCase();
      final normalized = _taskPriorities.contains(candidate)
          ? candidate
          : 'normal';
      onAddTask(title.trim(), normalized);
      return true;
    }
    return false;
  }

  /// Toggles completion status for an existing task.
  bool _executeToggleTask(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null) {
      onToggleTask(id);
      return true;
    }
    return false;
  }

  /// Deletes a task by ID.
  bool _executeDeleteTask(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null) {
      onDeleteTask(id);
      return true;
    }
    return false;
  }
}
