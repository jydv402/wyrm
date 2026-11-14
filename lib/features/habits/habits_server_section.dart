import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/features/habits/habit_form_content.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Habits feature's web remote surface: habit list REST routes, the
/// create/toggle/step/delete WebSocket commands, and the `habits` snapshot.
class HabitsServerSection implements ServerSection {
  final HabitsState Function() getHabits;
  final void Function(
    String title,
    HabitType type,
    int targetValue, {
    String? unit,
    String? iconName,
  })
  onAddHabit;
  final void Function(String id, [DateTime? date]) onToggleHabit;
  final void Function(String id, int delta, [DateTime? date]) onStepHabit;
  final void Function(String id) onDeleteHabit;

  HabitsServerSection({
    required this.getHabits,
    required this.onAddHabit,
    required this.onToggleHabit,
    required this.onStepHabit,
    required this.onDeleteHabit,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.get('/api/habits', (Request request) async {
      return jsonResponse(getHabits().habits.map((h) => h.toJson()).toList());
    });
    router.post('/api/habits', (Request request) async {
      try {
        if (_executeCreateHabit(await readJsonBody(request))) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid habit payload');
    });
    router.post('/api/habits/toggle', (Request request) async {
      try {
        final data = await readJsonBody(request);
        final dateStr = (data['date'] ?? data['target_date']) as String?;
        if (_executeToggleHabit(data['id'], dateStr)) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid toggle habit payload');
    });
    router.post('/api/habits/step', (Request request) async {
      try {
        final data = await readJsonBody(request);
        final dateStr = (data['date'] ?? data['target_date']) as String?;
        if (_executeStepHabit(data['id'], data['delta'], dateStr)) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid step habit payload');
    });
    router.post('/api/habits/delete', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeDeleteHabit(data['id'])) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid delete habit payload');
    });
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    switch (data['type'] as String?) {
      case 'create_habit':
        return _executeCreateHabit(data);
      case 'toggle_habit':
        return _executeToggleHabit(data['id'], data['date'] as String?);
      case 'step_habit':
        return _executeStepHabit(
          data['id'],
          data['delta'],
          data['date'] as String?,
        );
      case 'delete_habit':
        return _executeDeleteHabit(data['id']);
      default:
        return false;
    }
  }

  @override
  Map<String, dynamic>? snapshot() {
    return {'habits': getHabits().habits.map((h) => h.toJson()).toList()};
  }

  /// Parses habit parameters (handling field aliases) and triggers creation.
  bool _executeCreateHabit(Map<String, dynamic> data) {
    final title = (data['title'] ?? data['name']) as String?;
    final typeStr = (data['habit_type'] ?? data['type'] ?? 'binary') as String;
    final rawTarget =
        data['target_value'] ?? data['targetValue'] ?? data['target'];
    final targetValue = rawTarget is num
        ? rawTarget.toInt()
        : (int.tryParse(rawTarget?.toString() ?? '1') ?? 1);
    final unit = data['unit'] as String?;
    final rawIcon =
        (data['icon_name'] ?? data['iconName'] ?? data['glyph'] ?? 'bolt')
            .toString();
    final iconName = emojiToHabitIcon[rawIcon] ?? rawIcon;

    if (title != null && title.trim().isNotEmpty) {
      onAddHabit(
        title.trim(),
        HabitType.fromString(typeStr),
        targetValue,
        unit: unit?.trim().isEmpty == true ? null : unit?.trim(),
        iconName: iconName,
      );
      return true;
    }
    return false;
  }

  /// Toggles completion status for a habit on a specific date.
  bool _executeToggleHabit(dynamic idRaw, String? dateStr) {
    final id = idRaw?.toString();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (id != null) {
      onToggleHabit(id, date);
      return true;
    }
    return false;
  }

  /// Increments or decrements a numeric habit count by delta on a specific date.
  bool _executeStepHabit(dynamic idRaw, dynamic deltaRaw, String? dateStr) {
    final id = idRaw?.toString();
    final delta = deltaRaw is int
        ? deltaRaw
        : (int.tryParse(deltaRaw?.toString() ?? '1') ?? 1);
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (id != null) {
      onStepHabit(id, delta, date);
      return true;
    }
    return false;
  }

  /// Deletes a habit by ID.
  bool _executeDeleteHabit(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null) {
      onDeleteHabit(id);
      return true;
    }
    return false;
  }
}
