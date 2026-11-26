import 'dart:convert';

import 'package:wyrm_desk/core/notifications/reminder_model.dart';

/// Minimum snooze duration accepted from remote clients (in minutes).
const int minSnoozeMinutes = 1;

/// Maximum snooze duration accepted from remote clients (in minutes).
const int maxSnoozeMinutes = 120;

/// Default snooze duration when omitted by a snooze request (in minutes).
const int defaultSnoozeMinutes = 10;

/// Validated fields for a new reminder submitted over REST or WebSocket.
typedef ReminderDraft = ({
  String title,
  DateTime scheduledAt,
  ReminderRecurrence recurrence,
  List<int> customWeekdays,
  bool isEnabled,
});

/// Parsed partial update for an existing reminder.
class ReminderUpdatePlan {
  /// Fully edited item when any schedule field changed.
  final ReminderItem? editedItem;

  /// Enabled flag when the update only toggles the reminder.
  final bool? toggleOnlyEnabled;

  /// Snooze duration to apply after the edit or toggle.
  final int? snoozeMinutes;

  /// Creates a [ReminderUpdatePlan].
  const ReminderUpdatePlan({
    this.editedItem,
    this.toggleOnlyEnabled,
    this.snoozeMinutes,
  });
}

/// Parses a create payload, returning `null` for any malformed field.
ReminderDraft? parseReminderDraft(Map<String, dynamic> data) {
  final rawTitle = data['title'] ?? data['text'] ?? data['name'];
  if (rawTitle is! String) return null;
  final title = rawTitle.trim();
  if (title.isEmpty) return null;

  final scheduledAt = parseReminderDateTime(
    data['scheduled_at'] ?? data['scheduledAt'] ?? data['target_at'],
  );
  if (scheduledAt == null) return null;

  final rawRecurrence = data['recurrence'];
  if (rawRecurrence != null &&
      rawRecurrence is! String &&
      rawRecurrence is! ReminderRecurrence) {
    return null;
  }
  final recurrence = ReminderRecurrence.fromString(rawRecurrence);

  final parsedWeekdays = parseReminderWeekdays(
    data['custom_weekdays'] ?? data['customWeekdays'] ?? data['weekdays'],
  );
  if (parsedWeekdays == null) return null;
  final customWeekdays = recurrence == ReminderRecurrence.custom
      ? parsedWeekdays
      : const <int>[];
  if (recurrence == ReminderRecurrence.custom && customWeekdays.isEmpty) {
    return null;
  }

  final rawEnabled = data['is_enabled'] ?? data['isEnabled'] ?? data['enabled'];
  final isEnabled = rawEnabled == null ? true : parseReminderBool(rawEnabled);
  if (isEnabled == null) return null;

  return (
    title: title,
    scheduledAt: scheduledAt,
    recurrence: recurrence,
    customWeekdays: customWeekdays,
    isEnabled: isEnabled,
  );
}

/// Parses a partial update payload against [existing].
///
/// Returns `null` when the payload carries no recognised fields or any
/// recognised field is malformed.
ReminderUpdatePlan? parseReminderUpdatePlan(
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

  var nextTitle = existing.title;
  if (hasTitle) {
    final rawTitle = data['title'] ?? data['text'] ?? data['name'];
    if (rawTitle is! String) return null;
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return null;
    nextTitle = trimmed;
  }

  var nextScheduledAt = existing.scheduledAt;
  if (hasScheduled) {
    final parsed = parseReminderDateTime(
      data['scheduled_at'] ?? data['scheduledAt'] ?? data['target_at'],
    );
    if (parsed == null) return null;
    nextScheduledAt = parsed;
  }

  var nextRecurrence = existing.recurrence;
  if (hasRecurrence) {
    final rawRecurrence = data['recurrence'];
    if (rawRecurrence == null ||
        (rawRecurrence is! String && rawRecurrence is! ReminderRecurrence)) {
      return null;
    }
    nextRecurrence = ReminderRecurrence.fromString(rawRecurrence);
  }

  var nextWeekdays = existing.customWeekdays;
  if (hasWeekdays) {
    final parsed = parseReminderWeekdays(
      data['custom_weekdays'] ?? data['customWeekdays'] ?? data['weekdays'],
    );
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
    nextEnabled = parseReminderBool(
      data['is_enabled'] ?? data['isEnabled'] ?? data['enabled'],
    );
    if (nextEnabled == null) return null;
  }

  int? snoozeMinutes;
  if (hasSnooze) {
    final rawSnooze = data['snooze_minutes'] ?? data['snoozeMinutes'];
    if (rawSnooze == null) return null;
    snoozeMinutes = parseReminderSnoozeMinutes(
      rawSnooze,
      fallbackOnNull: false,
    );
    if (snoozeMinutes == null) return null;
  }

  final hasFieldEdits =
      hasTitle || hasScheduled || hasRecurrence || hasWeekdays;

  if (!hasFieldEdits && !hasSnooze && hasEnabled) {
    return ReminderUpdatePlan(toggleOnlyEnabled: nextEnabled);
  }

  if (!hasFieldEdits && hasSnooze) {
    return ReminderUpdatePlan(
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

  return ReminderUpdatePlan(
    editedItem: editedItem,
    snoozeMinutes: snoozeMinutes,
  );
}

/// Parses an ISO-8601 date-time from a string or passes through a [DateTime].
DateTime? parseReminderDateTime(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}

/// Parses and normalizes ISO weekdays (`1` = Monday … `7` = Sunday).
///
/// Missing input yields an empty list; malformed input yields `null`.
List<int>? parseReminderWeekdays(dynamic raw) {
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

/// Parses a lenient boolean (`true`/`false`, `1`/`0`, `"true"`/`"false"`).
bool? parseReminderBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is int && (raw == 0 || raw == 1)) return raw == 1;
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

/// Parses and clamps a snooze duration, defaulting to [defaultSnoozeMinutes]
/// when [raw] is `null` and [fallbackOnNull] is `true`.
int? parseReminderSnoozeMinutes(dynamic raw, {bool fallbackOnNull = true}) {
  if (raw == null) return fallbackOnNull ? defaultSnoozeMinutes : null;
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

/// Decodes [rawBody] into a JSON object, or returns `null` when invalid.
Map<String, dynamic>? decodeReminderJsonMap(String rawBody) {
  try {
    final decoded = jsonDecode(rawBody);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
