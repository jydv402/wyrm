import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Reminders feature's web remote surface: reminder CRUD and alarm control
/// REST routes, `reminder_*` WebSocket commands, and the `reminders` /
/// `active_alarm` snapshot slices.
class ReminderServerSection implements ServerSection {
  /// Canonical snapshot key owned by this section.
  static const String sectionKey = 'reminders';

  /// Minimum snooze duration accepted from remote clients (in minutes).
  static const int minSnoozeMinutes = 1;

  /// Maximum snooze duration accepted from remote clients (in minutes).
  static const int maxSnoozeMinutes = 120;

  /// Default snooze duration when omitted by a snooze request (in minutes).
  static const int defaultSnoozeMinutes = 10;

  /// Injected clock used when fallback snooze computation is needed.
  final Clock clock;

  /// Reads the current reminder list state.
  final RemindersState Function() getReminders;

  /// Reads the currently ringing alarm, or `null` when idle.
  final ActiveAlarmState? Function() getActiveAlarm;

  /// Creates and persists a new reminder.
  final FutureOr<ReminderItem> Function({
    required String title,
    required DateTime scheduledAt,
    ReminderRecurrence recurrence,
    List<int> customWeekdays,
    bool isEnabled,
  })
  onAddReminder;

  /// Replaces an existing reminder.
  final FutureOr<void> Function(ReminderItem reminder) onEditReminder;

  /// Toggles or explicitly sets `isEnabled` for a reminder by ID.
  final FutureOr<void> Function(String id, [bool? isEnabled]) onToggleReminder;

  /// Deletes a reminder by ID.
  final FutureOr<void> Function(String id) onDeleteReminder;

  /// Snoozes a specific reminder by ID for the given duration.
  final FutureOr<void> Function(String id, Duration duration)? onSnoozeReminder;

  /// Dismisses the currently ringing alarm if one is active.
  final FutureOr<void> Function() onDismissAlarm;

  /// Snoozes the currently ringing alarm for the given duration.
  final FutureOr<void> Function(Duration duration) onSnoozeAlarm;

  /// Creates a [ReminderServerSection].
  ReminderServerSection({
    this.clock = const Clock(),
    required this.getReminders,
    required this.getActiveAlarm,
    required this.onAddReminder,
    required this.onEditReminder,
    required this.onToggleReminder,
    required this.onDeleteReminder,
    this.onSnoozeReminder,
    required this.onDismissAlarm,
    required this.onSnoozeAlarm,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.get('/api/reminders', (Request request) {
      return jsonResponse(snapshot());
    });

    router.post('/api/reminders', _handleCreateReminder);

    router.post('/api/reminders/alarm/dismiss', _handleDismissAlarm);

    router.post('/api/reminders/alarm/snooze', _handleSnoozeAlarm);

    router.put('/api/reminders/<id>', _handleUpdateReminder);

    router.delete('/api/reminders/<id>', _handleDeleteReminder);
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    final type = data['type'];
    if (type is! String) return false;

    switch (type) {
      case 'reminder_add':
        final parsed = _parseAddPayload(data);
        if (parsed == null) return false;
        _fireAndForget(
          () => onAddReminder(
            title: parsed.title,
            scheduledAt: parsed.scheduledAt,
            recurrence: parsed.recurrence,
            customWeekdays: parsed.customWeekdays,
            isEnabled: parsed.isEnabled,
          ),
        );
        return true;

      case 'reminder_edit':
        final existing = _findByIdRaw(data['id']);
        if (existing == null) return false;
        final plan = _parseUpdatePlan(existing, data);
        if (plan == null) return false;
        _fireAndForget(() => _applyUpdatePlan(existing, plan));
        return true;

      case 'reminder_toggle':
        final existing = _findByIdRaw(data['id']);
        if (existing == null) return false;
        final hasEnabled =
            data.containsKey('is_enabled') ||
            data.containsKey('isEnabled') ||
            data.containsKey('enabled');
        bool? nextEnabled;
        if (hasEnabled) {
          nextEnabled = _parseBoolStrict(
            data['is_enabled'] ?? data['isEnabled'] ?? data['enabled'],
          );
          if (nextEnabled == null) return false;
        }
        _fireAndForget(() => onToggleReminder(existing.id, nextEnabled));
        return true;

      case 'reminder_delete':
        final existing = _findByIdRaw(data['id']);
        if (existing == null) return false;
        _fireAndForget(() => onDeleteReminder(existing.id));
        return true;

      case 'reminder_dismiss_alarm':
        _fireAndForget(onDismissAlarm);
        return true;

      case 'reminder_snooze_alarm':
        final minutes = _parseSnoozeMinutes(
          data['minutes'] ?? data['snooze_minutes'],
        );
        if (minutes == null) return false;
        _fireAndForget(() => onSnoozeAlarm(Duration(minutes: minutes)));
        return true;

      default:
        return false;
    }
  }

  @override
  Map<String, dynamic>? snapshot() {
    return <String, dynamic>{
      'reminders': getReminders().items.map((item) => item.toJson()).toList(),
      'active_alarm': getActiveAlarm()?.toJson(),
    };
  }

  Future<Response> _handleCreateReminder(Request request) async {
    final Map<String, dynamic> data;
    try {
      data = await readJsonBody(request);
    } catch (_) {
      return jsonError('Invalid reminder payload');
    }

    final parsed = _parseAddPayload(data);
    if (parsed == null) {
      return jsonError('Invalid reminder payload');
    }

    final created = await onAddReminder(
      title: parsed.title,
      scheduledAt: parsed.scheduledAt,
      recurrence: parsed.recurrence,
      customWeekdays: parsed.customWeekdays,
      isEnabled: parsed.isEnabled,
    );
    return jsonOk(<String, dynamic>{
      'reminder': created.toJson(),
      ...?snapshot(),
    });
  }

  Future<Response> _handleUpdateReminder(Request request, String id) async {
    final existing = _findById(id);
    if (existing == null) {
      return jsonError('Reminder not found', statusCode: 404);
    }

    final Map<String, dynamic> data;
    try {
      data = await readJsonBody(request);
    } catch (_) {
      return jsonError('Invalid reminder update payload');
    }

    final plan = _parseUpdatePlan(existing, data);
    if (plan == null) {
      return jsonError('Invalid reminder update payload');
    }

    await _applyUpdatePlan(existing, plan);
    final updated = _findById(existing.id) ?? existing;
    return jsonOk(<String, dynamic>{
      'reminder': updated.toJson(),
      ...?snapshot(),
    });
  }

  Future<Response> _handleDeleteReminder(Request request, String id) async {
    final existing = _findById(id);
    if (existing == null) {
      return jsonError('Reminder not found', statusCode: 404);
    }

    await onDeleteReminder(existing.id);
    return jsonOk(<String, dynamic>{'deleted_id': existing.id, ...?snapshot()});
  }

  Future<Response> _handleDismissAlarm(Request request) async {
    await onDismissAlarm();
    return jsonOk(<String, dynamic>{'ok': true, ...?snapshot()});
  }

  Future<Response> _handleSnoozeAlarm(Request request) async {
    Map<String, dynamic> data = const <String, dynamic>{};
    try {
      final rawBody = await request.readAsString();
      if (rawBody.trim().isNotEmpty) {
        final decoded = _decodeJsonMap(rawBody);
        if (decoded == null) {
          return jsonError('Invalid snooze payload');
        }
        data = decoded;
      }
    } catch (_) {
      return jsonError('Invalid snooze payload');
    }

    final minutes = _parseSnoozeMinutes(
      data['minutes'] ?? data['snooze_minutes'],
    );
    if (minutes == null) {
      return jsonError('Invalid snooze minutes');
    }

    await onSnoozeAlarm(Duration(minutes: minutes));
    return jsonOk(<String, dynamic>{
      'ok': true,
      'minutes': minutes,
      ...?snapshot(),
    });
  }

  ReminderItem? _findByIdRaw(dynamic idRaw) {
    if (idRaw == null) return null;
    final id = idRaw.toString().trim();
    if (id.isEmpty) return null;
    return _findById(id);
  }

  ReminderItem? _findById(String id) {
    for (final item in getReminders().items) {
      if (item.id == id) return item;
    }
    return null;
  }

  ({
    String title,
    DateTime scheduledAt,
    ReminderRecurrence recurrence,
    List<int> customWeekdays,
    bool isEnabled,
  })?
  _parseAddPayload(Map<String, dynamic> data) {
    final rawTitle = data['title'] ?? data['text'] ?? data['name'];
    if (rawTitle is! String) return null;
    final title = rawTitle.trim();
    if (title.isEmpty) return null;

    final rawScheduled =
        data['scheduled_at'] ?? data['scheduledAt'] ?? data['target_at'];
    final scheduledAt = _parseDateTimeStrict(rawScheduled);
    if (scheduledAt == null) return null;

    final rawRecurrence = data['recurrence'];
    if (rawRecurrence != null &&
        rawRecurrence is! String &&
        rawRecurrence is! ReminderRecurrence) {
      return null;
    }
    final recurrence = ReminderRecurrence.fromString(rawRecurrence);

    final rawWeekdays =
        data['custom_weekdays'] ?? data['customWeekdays'] ?? data['weekdays'];
    final parsedWeekdays = _parseWeekdaysStrict(rawWeekdays);
    if (parsedWeekdays == null) return null;
    final customWeekdays = recurrence == ReminderRecurrence.custom
        ? parsedWeekdays
        : const <int>[];
    if (recurrence == ReminderRecurrence.custom && customWeekdays.isEmpty) {
      return null;
    }

    final rawEnabled =
        data['is_enabled'] ?? data['isEnabled'] ?? data['enabled'];
    final isEnabled = rawEnabled == null ? true : _parseBoolStrict(rawEnabled);
    if (isEnabled == null) return null;

    return (
      title: title,
      scheduledAt: scheduledAt,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
      isEnabled: isEnabled,
    );
  }

  _ReminderUpdatePlan? _parseUpdatePlan(
    ReminderItem existing,
    Map<String, dynamic> data,
  ) {
    final hasTitle =
        data.containsKey('title') ||
        data.containsKey('text') ||
        data.containsKey('name');
    final hasScheduled =
        data.containsKey('scheduled_at') ||
        data.containsKey('scheduledAt') ||
        data.containsKey('target_at');
    final hasRecurrence = data.containsKey('recurrence');
    final hasWeekdays =
        data.containsKey('custom_weekdays') ||
        data.containsKey('customWeekdays') ||
        data.containsKey('weekdays');
    final hasEnabled =
        data.containsKey('is_enabled') ||
        data.containsKey('isEnabled') ||
        data.containsKey('enabled');
    final hasSnooze =
        data.containsKey('snooze_minutes') || data.containsKey('snoozeMinutes');

    if (!hasTitle &&
        !hasScheduled &&
        !hasRecurrence &&
        !hasWeekdays &&
        !hasEnabled &&
        !hasSnooze) {
      return null;
    }

    String nextTitle = existing.title;
    if (hasTitle) {
      final rawTitle = data['title'] ?? data['text'] ?? data['name'];
      if (rawTitle is! String) return null;
      final trimmed = rawTitle.trim();
      if (trimmed.isEmpty) return null;
      nextTitle = trimmed;
    }

    DateTime nextScheduledAt = existing.scheduledAt;
    if (hasScheduled) {
      final rawScheduled =
          data['scheduled_at'] ?? data['scheduledAt'] ?? data['target_at'];
      final parsed = _parseDateTimeStrict(rawScheduled);
      if (parsed == null) return null;
      nextScheduledAt = parsed;
    }

    ReminderRecurrence nextRecurrence = existing.recurrence;
    if (hasRecurrence) {
      final rawRecurrence = data['recurrence'];
      if (rawRecurrence == null ||
          (rawRecurrence is! String && rawRecurrence is! ReminderRecurrence)) {
        return null;
      }
      nextRecurrence = ReminderRecurrence.fromString(rawRecurrence);
    }

    List<int> nextWeekdays = existing.customWeekdays;
    if (hasWeekdays) {
      final rawWeekdays =
          data['custom_weekdays'] ?? data['customWeekdays'] ?? data['weekdays'];
      final parsed = _parseWeekdaysStrict(rawWeekdays);
      if (parsed == null) return null;
      nextWeekdays = parsed;
    }

    if (nextRecurrence == ReminderRecurrence.custom) {
      if (nextWeekdays.isEmpty) return null;
    } else {
      nextWeekdays = const <int>[];
    }

    bool? nextEnabled;
    if (hasEnabled) {
      nextEnabled = _parseBoolStrict(
        data['is_enabled'] ?? data['isEnabled'] ?? data['enabled'],
      );
      if (nextEnabled == null) return null;
    }

    int? snoozeMinutes;
    if (hasSnooze) {
      final rawSnooze = data['snooze_minutes'] ?? data['snoozeMinutes'];
      if (rawSnooze == null) return null;
      snoozeMinutes = _parseSnoozeMinutes(rawSnooze);
      if (snoozeMinutes == null) return null;
    }

    final hasFieldEdits =
        hasTitle || hasScheduled || hasRecurrence || hasWeekdays;

    if (!hasFieldEdits && !hasSnooze && hasEnabled) {
      return _ReminderUpdatePlan(toggleOnlyEnabled: nextEnabled);
    }

    if (!hasFieldEdits && hasSnooze) {
      return _ReminderUpdatePlan(
        toggleOnlyEnabled: nextEnabled,
        snoozeMinutes: snoozeMinutes,
      );
    }

    final scheduleChanged =
        hasScheduled && nextScheduledAt != existing.scheduledAt;
    final editedItem = existing.copyWith(
      title: nextTitle,
      scheduledAt: nextScheduledAt,
      recurrence: nextRecurrence,
      customWeekdays: nextWeekdays,
      isEnabled: nextEnabled ?? existing.isEnabled,
      clearSnoozedUntil: !hasSnooze,
      clearLastTriggeredAt: scheduleChanged,
    );

    return _ReminderUpdatePlan(
      editedItem: editedItem,
      snoozeMinutes: snoozeMinutes,
    );
  }

  Future<void> _applyUpdatePlan(
    ReminderItem existing,
    _ReminderUpdatePlan plan,
  ) async {
    var current = existing;
    if (plan.editedItem != null) {
      current = plan.editedItem!;
      await onEditReminder(current);
    } else if (plan.toggleOnlyEnabled != null) {
      await onToggleReminder(existing.id, plan.toggleOnlyEnabled);
      current = _findById(existing.id) ?? existing;
    }

    if (plan.snoozeMinutes != null) {
      final duration = Duration(minutes: plan.snoozeMinutes!);
      if (onSnoozeReminder != null) {
        await onSnoozeReminder!(existing.id, duration);
      } else {
        final now = clock.now();
        await onEditReminder(
          current.copyWith(
            isEnabled: true,
            snoozedUntil: now.add(duration),
            lastTriggeredAt: current.lastTriggeredAt ?? now,
          ),
        );
      }
    }
  }

  static void _fireAndForget(FutureOr<Object?> Function() action) {
    try {
      final result = action();
      if (result is Future<Object?>) {
        unawaited(result.then<void>((_) {}, onError: (Object _) {}));
      }
    } catch (_) {}
  }

  static DateTime? _parseDateTimeStrict(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  static List<int>? _parseWeekdaysStrict(dynamic raw) {
    if (raw == null) return const <int>[];
    if (raw is! Iterable) return null;
    final parsed = <int>[];
    for (final entry in raw) {
      if (entry is int) {
        parsed.add(entry);
      } else if (entry is num && entry.isFinite && entry == entry.truncate()) {
        parsed.add(entry.toInt());
      } else if (entry is String) {
        final value = int.tryParse(entry.trim());
        if (value == null) return null;
        parsed.add(value);
      } else {
        return null;
      }
    }
    return ReminderItem.normalizeWeekdays(parsed);
  }

  static bool? _parseBoolStrict(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is int && (raw == 0 || raw == 1)) return raw == 1;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static int? _parseSnoozeMinutes(dynamic raw) {
    if (raw == null) return defaultSnoozeMinutes;
    int? parsed;
    if (raw is int) {
      parsed = raw;
    } else if (raw is num) {
      if (!raw.isFinite) return null;
      parsed = raw.round();
    } else if (raw is String) {
      parsed = int.tryParse(raw.trim());
    }
    if (parsed == null) return null;
    return parsed.clamp(minSnoozeMinutes, maxSnoozeMinutes);
  }

  static Map<String, dynamic>? _decodeJsonMap(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class _ReminderUpdatePlan {
  final ReminderItem? editedItem;
  final bool? toggleOnlyEnabled;
  final int? snoozeMinutes;

  const _ReminderUpdatePlan({
    this.editedItem,
    this.toggleOnlyEnabled,
    this.snoozeMinutes,
  });
}
