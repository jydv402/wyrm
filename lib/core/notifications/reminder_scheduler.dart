import 'dart:convert';

import 'package:wyrm_desk/core/notifications/deterministic_id.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';

/// Immutable notification schedule item produced by [ReminderScheduler].
class ScheduledReminderRequest {
  /// Deterministic positive 31-bit notification ID.
  final int notificationId;

  /// Identifier of the owning [ReminderItem].
  final String reminderId;

  /// Title rendered in the OS notification.
  final String title;

  /// Supporting body text rendered in the OS notification.
  final String body;

  /// Resolved fire instant.
  final DateTime fireAt;

  /// Serializable JSON payload embedding reminder ID and occurrence timestamp.
  final String payloadJson;

  /// Creates a [ScheduledReminderRequest].
  const ScheduledReminderRequest({
    required this.notificationId,
    required this.reminderId,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.payloadJson,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduledReminderRequest &&
        other.notificationId == notificationId &&
        other.reminderId == reminderId &&
        other.title == title &&
        other.body == body &&
        other.fireAt == fireAt &&
        other.payloadJson == payloadJson;
  }

  @override
  int get hashCode =>
      Object.hash(notificationId, reminderId, title, body, fireAt, payloadJson);
}

/// Pure, side-effect-free scheduling math for [ReminderItem]s.
///
/// All methods accept an explicit `now` timestamp so tests stay deterministic
/// without reading the global wall clock.
abstract final class ReminderScheduler {
  /// Default forward scan horizon in calendar days for repeating reminders.
  static const int maxHorizonDays = 14;

  /// Default total OS notification budget (leaves headroom under iOS 64-cap).
  static const int defaultMaxTotalSlots = 48;

  /// Returns the exact fired [DateTime] target if [item] is currently due at
  /// [now], or `null` otherwise.
  ///
  /// - Disabled items return `null`.
  /// - Active [ReminderItem.snoozedUntil] takes precedence over the regular
  ///   recurrence schedule (returning `null` while still in the future).
  /// - One-time reminders return [ReminderItem.scheduledAt] once `now` reaches
  ///   it and [ReminderItem.lastTriggeredAt] is null or strictly before it.
  /// - Repeating reminders check today's local wall-clock candidate within
  ///   [catchUpWindow] when today's weekday matches the rule and
  ///   [ReminderItem.lastTriggeredAt] is null or strictly before that candidate.
  static DateTime? currentDueOccurrence(
    ReminderItem item, {
    required DateTime now,
    Duration catchUpWindow = const Duration(minutes: 2),
  }) {
    if (!item.isEnabled) return null;

    final snooze = item.snoozedUntil;
    if (snooze != null) {
      if (now.isBefore(snooze)) {
        return null;
      }
      if (!_wasTriggeredForCandidate(item.lastTriggeredAt, snooze)) {
        return snooze;
      }
      return null;
    }

    if (item.recurrence == ReminderRecurrence.once) {
      final target = item.scheduledAt;
      if (now.isBefore(target)) {
        return null;
      }
      if (!_wasTriggeredForCandidate(item.lastTriggeredAt, target)) {
        return target;
      }
      return null;
    }

    final candidate = _wallClockOnDay(now, item.scheduledAt, dayOffset: 0);
    if (!item.matchesWeekday(candidate.weekday)) {
      return null;
    }
    if (now.isBefore(candidate)) {
      return null;
    }
    if (now.difference(candidate) > catchUpWindow) {
      return null;
    }
    if (_wasTriggeredForCandidate(item.lastTriggeredAt, candidate)) {
      return null;
    }
    return candidate;
  }

  /// Whether [item] should trigger at [now].
  static bool isDueNow(
    ReminderItem item, {
    required DateTime now,
    Duration catchUpWindow = const Duration(minutes: 2),
  }) {
    return currentDueOccurrence(item, now: now, catchUpWindow: catchUpWindow) !=
        null;
  }

  /// Returns the next future fire instant strictly after [now], or `null` when
  /// [item] is disabled or has no upcoming occurrences within the scan horizon.
  static DateTime? nextFireAt(ReminderItem item, {required DateTime now}) {
    if (!item.isEnabled) return null;

    final snooze = item.snoozedUntil;
    if (snooze != null &&
        snooze.isAfter(now) &&
        !_wasTriggeredForCandidate(item.lastTriggeredAt, snooze)) {
      return snooze;
    }

    if (item.recurrence == ReminderRecurrence.once) {
      final target = item.scheduledAt;
      if (target.isAfter(now) &&
          !_wasTriggeredForCandidate(item.lastTriggeredAt, target)) {
        return target;
      }
      return null;
    }

    for (var dayOffset = 0; dayOffset <= maxHorizonDays; dayOffset++) {
      final candidate = _wallClockOnDay(
        now,
        item.scheduledAt,
        dayOffset: dayOffset,
      );
      if (!item.matchesWeekday(candidate.weekday)) continue;
      if (!candidate.isAfter(now)) continue;
      if (_wasTriggeredForCandidate(item.lastTriggeredAt, candidate)) continue;
      return candidate;
    }
    return null;
  }

  /// Builds the sorted upcoming notification schedule across [items], capped at
  /// [maxTotalSlots] nearest future instants.
  static List<ScheduledReminderRequest> buildScheduleWindow(
    List<ReminderItem> items, {
    required DateTime now,
    int maxTotalSlots = defaultMaxTotalSlots,
  }) {
    if (maxTotalSlots <= 0 || items.isEmpty) {
      return const <ScheduledReminderRequest>[];
    }

    final candidates = <ScheduledReminderRequest>[];
    for (final item in items) {
      if (!item.isEnabled) continue;

      final seenEpochs = <int>{};
      final snooze = item.snoozedUntil;
      DateTime? snoozeCutoff;

      if (snooze != null &&
          snooze.isAfter(now) &&
          !_wasTriggeredForCandidate(item.lastTriggeredAt, snooze)) {
        seenEpochs.add(snooze.millisecondsSinceEpoch);
        snoozeCutoff = snooze;
        candidates.add(
          _buildRequest(item: item, fireAt: snooze, isSnoozed: true),
        );
      }

      if (item.recurrence == ReminderRecurrence.once) {
        final target = item.scheduledAt;
        if (snoozeCutoff == null &&
            target.isAfter(now) &&
            !_wasTriggeredForCandidate(item.lastTriggeredAt, target) &&
            seenEpochs.add(target.millisecondsSinceEpoch)) {
          candidates.add(
            _buildRequest(item: item, fireAt: target, isSnoozed: false),
          );
        }
        continue;
      }

      for (var dayOffset = 0; dayOffset <= maxHorizonDays; dayOffset++) {
        final candidate = _wallClockOnDay(
          now,
          item.scheduledAt,
          dayOffset: dayOffset,
        );
        if (!item.matchesWeekday(candidate.weekday)) continue;
        if (!candidate.isAfter(now)) continue;
        if (snoozeCutoff != null && !candidate.isAfter(snoozeCutoff)) continue;
        if (_wasTriggeredForCandidate(item.lastTriggeredAt, candidate)) {
          continue;
        }
        if (seenEpochs.add(candidate.millisecondsSinceEpoch)) {
          candidates.add(
            _buildRequest(item: item, fireAt: candidate, isSnoozed: false),
          );
        }
      }
    }

    candidates.sort((a, b) {
      final timeOrder = a.fireAt.compareTo(b.fireAt);
      if (timeOrder != 0) return timeOrder;
      return a.reminderId.compareTo(b.reminderId);
    });

    if (candidates.length > maxTotalSlots) {
      return List<ScheduledReminderRequest>.unmodifiable(
        candidates.sublist(0, maxTotalSlots),
      );
    }
    return List<ScheduledReminderRequest>.unmodifiable(candidates);
  }

  static ScheduledReminderRequest _buildRequest({
    required ReminderItem item,
    required DateTime fireAt,
    required bool isSnoozed,
  }) {
    final title = item.title.trim().isEmpty ? 'Reminder' : item.title.trim();
    final body = isSnoozed
        ? 'Snoozed alarm'
        : '${item.recurrence.label} reminder';
    final payloadJson = jsonEncode(<String, dynamic>{
      'reminder_id': item.id,
      'occurrence_epoch_ms': fireAt.millisecondsSinceEpoch,
      'title': title,
    });
    return ScheduledReminderRequest(
      notificationId: deterministicNotificationId(item.id, fireAt),
      reminderId: item.id,
      title: title,
      body: body,
      fireAt: fireAt,
      payloadJson: payloadJson,
    );
  }

  /// Constructs the wall-clock candidate on `now`'s calendar day + [dayOffset],
  /// matching `now`'s UTC/local mode so DST transitions keep the wall hour.
  static DateTime _wallClockOnDay(
    DateTime now,
    DateTime scheduledAt, {
    required int dayOffset,
  }) {
    final anchor = now.isUtc ? scheduledAt.toUtc() : scheduledAt.toLocal();
    if (now.isUtc) {
      return DateTime.utc(
        now.year,
        now.month,
        now.day + dayOffset,
        anchor.hour,
        anchor.minute,
      );
    }
    return DateTime(
      now.year,
      now.month,
      now.day + dayOffset,
      anchor.hour,
      anchor.minute,
    );
  }

  static bool _wasTriggeredForCandidate(
    DateTime? lastTriggeredAt,
    DateTime candidate,
  ) {
    if (lastTriggeredAt == null) return false;
    return !lastTriggeredAt.isBefore(candidate);
  }
}
