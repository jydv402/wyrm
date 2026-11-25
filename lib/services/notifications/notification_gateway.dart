import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/services/notifications/fln_notification_gateway.dart';

/// Notification tap or shade action event forwarded by [NotificationGateway].
class NotificationTapEvent {
  /// Action identifier (`'dismiss'`, `'snooze'`), or `null` when body tapped.
  final String? actionId;

  /// Raw serialized payload string attached to the notification.
  final String? payload;

  /// Optional platform notification ID.
  final int? notificationId;

  /// Creates a [NotificationTapEvent].
  const NotificationTapEvent({
    this.actionId,
    this.payload,
    this.notificationId,
  });

  /// Decodes [payload] as a JSON map when valid, or `null` otherwise.
  Map<String, dynamic>? get payloadMap {
    final raw = payload;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the `reminder_id` encoded in [payload], if present.
  String? get reminderId {
    final raw = payloadMap?['reminder_id'] ?? payloadMap?['reminderId'];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return id.isEmpty ? null : id;
  }

  /// Extracts the occurrence timestamp encoded in [payload], if present.
  DateTime? get occurrenceAt {
    final raw =
        payloadMap?['occurrence_epoch_ms'] ?? payloadMap?['occurrenceEpochMs'];
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationTapEvent &&
        other.actionId == actionId &&
        other.payload == payload &&
        other.notificationId == notificationId;
  }

  @override
  int get hashCode => Object.hash(actionId, payload, notificationId);
}

/// Current OS permission state relevant to background reminder delivery.
class NotificationPermissionStatus {
  /// Whether posting notifications is enabled/granted by the OS.
  final bool notificationsEnabled;

  /// Whether scheduling exact alarms (`SCHEDULE_EXACT_ALARM`) is permitted.
  final bool exactAlarmsAllowed;

  /// Creates a [NotificationPermissionStatus].
  const NotificationPermissionStatus({
    this.notificationsEnabled = false,
    this.exactAlarmsAllowed = false,
  });

  /// Returns a copy with updated permission flags.
  NotificationPermissionStatus copyWith({
    bool? notificationsEnabled,
    bool? exactAlarmsAllowed,
  }) {
    return NotificationPermissionStatus(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed ?? this.exactAlarmsAllowed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPermissionStatus &&
        other.notificationsEnabled == notificationsEnabled &&
        other.exactAlarmsAllowed == exactAlarmsAllowed;
  }

  @override
  int get hashCode => Object.hash(notificationsEnabled, exactAlarmsAllowed);
}

/// Platform port isolating local notification scheduling and permissions from
/// pure domain logic and tests.
abstract interface class NotificationGateway {
  /// Initializes the underlying notification plugin, timezone DB, and channels.
  Future<void> initialize();

  /// Resolves and applies the device's local IANA timezone identifier.
  Future<String> resolveLocalTimezone();

  /// Queries current OS notification and exact-alarm permissions.
  Future<NotificationPermissionStatus> permissionStatus();

  /// Prompts the user for notification display permission when supported.
  Future<bool> requestNotificationsPermission();

  /// Opens or prompts for exact-alarm scheduling permission when supported.
  Future<bool> requestExactAlarmsPermission();

  /// Opens system notification settings when supported by the platform.
  Future<bool> openSystemNotificationSettings();

  /// Schedules a single notification described by [request].
  Future<void> zonedSchedule(
    ScheduledReminderRequest request, {
    bool exact = false,
  });

  /// Cancels a single pending or displayed notification by [id].
  Future<void> cancel(int id);

  /// Cancels all pending and displayed notifications for this application.
  Future<void> cancelAll();

  /// Returns all notification IDs currently pending in the OS scheduler cache.
  Future<List<int>> pendingNotificationIds();

  /// Returns the notification event that cold-launched the app, if any.
  Future<NotificationTapEvent?> getLaunchEvent();

  /// Stream of foreground notification taps and shade action invocations.
  Stream<NotificationTapEvent> get responses;
}

/// Idempotent reconcile entrypoint synchronizing [reminders] into [gateway].
///
/// Computes desired slots via [ReminderScheduler.buildScheduleWindow], cancels
/// stale pending IDs not in the desired set, and schedules missing desired
/// notifications (choosing exact vs inexact mode from [NotificationPermissionStatus]).
Future<void> syncNotifications({
  required NotificationGateway gateway,
  required List<ReminderItem> reminders,
  required DateTime now,
  int maxTotalSlots = ReminderScheduler.defaultMaxTotalSlots,
  bool forceReschedule = false,
}) async {
  final desired = ReminderScheduler.buildScheduleWindow(
    reminders,
    now: now,
    maxTotalSlots: maxTotalSlots,
  );
  final desiredIds = <int>{for (final item in desired) item.notificationId};
  final pendingIds = await gateway.pendingNotificationIds();
  final pendingIdSet = pendingIds.toSet();

  for (final pendingId in pendingIdSet) {
    if (forceReschedule || !desiredIds.contains(pendingId)) {
      await gateway.cancel(pendingId);
    }
  }

  if (desired.isEmpty) {
    return;
  }

  final status = await gateway.permissionStatus();
  for (final request in desired) {
    if (forceReschedule || !pendingIdSet.contains(request.notificationId)) {
      await gateway.zonedSchedule(request, exact: status.exactAlarmsAllowed);
    }
  }
}

/// Clears all stale OS notifications after backup/restore and rebuilds the
/// pending notification cache solely from [reminders].
Future<void> rebuildNotificationsAfterRestore({
  required NotificationGateway gateway,
  required List<ReminderItem> reminders,
  required DateTime now,
  int maxTotalSlots = ReminderScheduler.defaultMaxTotalSlots,
}) async {
  await gateway.cancelAll();
  await syncNotifications(
    gateway: gateway,
    reminders: reminders,
    now: now,
    maxTotalSlots: maxTotalSlots,
  );
}

/// Riverpod provider exposing [NotificationGateway] (overridden in tests).
final notificationGatewayProvider = Provider<NotificationGateway>((ref) {
  final gateway = FlnNotificationGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});
