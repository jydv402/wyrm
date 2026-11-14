import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Calendar feature's web remote surface: milestone REST routes, the
/// create/delete/pin WebSocket commands, and the `calendar` snapshot slice.
class CalendarServerSection implements ServerSection {
  final CalendarState Function() getCalendar;
  final bool Function() getStartWeekOnMonday;
  final void Function(String title, DateTime targetDate, {bool isPinned})
  onAddMilestone;
  final void Function(String id) onDeleteMilestone;
  final void Function(String id) onTogglePinMilestone;

  CalendarServerSection({
    required this.getCalendar,
    required this.getStartWeekOnMonday,
    required this.onAddMilestone,
    required this.onDeleteMilestone,
    required this.onTogglePinMilestone,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.get('/api/calendar', (Request request) {
      return jsonResponse(
        _serializeCalendarState(getCalendar(), getStartWeekOnMonday()),
      );
    });
    router.post('/api/calendar/milestones', (Request request) async {
      try {
        final data = await readJsonBody(request);
        final title = (data['title'] ?? data['name']) as String?;
        final dateStr =
            (data['target_date'] ?? data['targetDate'] ?? data['date'])
                as String?;
        final isPinned =
            (data['is_pinned'] ?? data['isPinned'] ?? false) as bool;
        if (_executeCreateMilestone(title, dateStr, isPinned)) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid milestone payload');
    });
    router.post('/api/calendar/milestones/delete', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeDeleteMilestone(data['id'])) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid delete milestone payload');
    });
    router.post('/api/calendar/milestones/pin', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeTogglePinMilestone(data['id'])) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid pin milestone payload');
    });
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    switch (data['type'] as String?) {
      case 'create_milestone':
        return _executeCreateMilestone(
          data['title'] as String?,
          (data['target_date'] ?? data['targetDate'] ?? data['date'])
              as String?,
          (data['is_pinned'] ?? data['isPinned'] ?? false) as bool,
        );
      case 'delete_milestone':
        return _executeDeleteMilestone(data['id']);
      case 'toggle_pin_milestone':
        return _executeTogglePinMilestone(data['id']);
      default:
        return false;
    }
  }

  @override
  Map<String, dynamic>? snapshot() {
    return {
      'calendar': _serializeCalendarState(
        getCalendar(),
        getStartWeekOnMonday(),
      ),
    };
  }

  /// Serializes calendar state into JSON, computing fallback metrics if null.
  Map<String, dynamic> _serializeCalendarState(
    CalendarState? cal,
    bool startWeekOnMonday,
  ) {
    if (cal == null) {
      final now = DateTime.now();
      return {
        'today': now.toIso8601String(),
        'yearProgress': 0.0,
        'quarterProgress': 0.0,
        'dayOfYear': 1,
        'daysInYear': 365,
        'currentQuarter': 1,
        'startWeekOnMonday': startWeekOnMonday,
        'milestones': <dynamic>[],
      };
    }
    return {
      'today': DateTime.now().toIso8601String(),
      'selectedDate': cal.selectedDate.toIso8601String(),
      'viewMonth': cal.viewMonth.toIso8601String(),
      'yearProgress': cal.yearProgress,
      'quarterProgress': cal.quarterProgress,
      'dayOfYear': cal.dayOfYear,
      'daysInYear': cal.daysInYear,
      'currentQuarter': cal.currentQuarter,
      'startWeekOnMonday': startWeekOnMonday,
      'milestones': cal.milestones.map((m) => m.toJson()).toList(),
    };
  }

  /// Creates a calendar milestone with flexible date string parsing.
  bool _executeCreateMilestone(String? title, String? dateStr, bool isPinned) {
    if (title != null && title.trim().isNotEmpty) {
      final targetDate = parseMilestoneDate(dateStr);
      onAddMilestone(title.trim(), targetDate, isPinned: isPinned);
      return true;
    }
    return false;
  }

  /// Deletes a milestone by ID.
  bool _executeDeleteMilestone(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null) {
      onDeleteMilestone(id);
      return true;
    }
    return false;
  }

  /// Toggles pinned status for a milestone by ID.
  bool _executeTogglePinMilestone(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null) {
      onTogglePinMilestone(id);
      return true;
    }
    return false;
  }
}

/// Tolerantly parses milestone date strings formatted in ISO-8601
/// (yyyy-mm-dd) or dd/mm/yyyy, falling back to now for unusable input.
DateTime parseMilestoneDate(String? dateStr) {
  if (dateStr == null || dateStr.trim().isEmpty) {
    return DateTime.now();
  }
  final trimmed = dateStr.trim();
  final isoParsed = DateTime.tryParse(trimmed);
  if (isoParsed != null) return isoParsed;

  final delimiter = trimmed.contains('/')
      ? '/'
      : (trimmed.contains('-') ? '-' : null);
  if (delimiter != null) {
    final parts = trimmed.split(delimiter);
    if (parts.length == 3 && parts[2].length == 4) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
  }
  return DateTime.now();
}
