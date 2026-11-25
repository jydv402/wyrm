import 'dart:async';

import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

/// Recorded scheduled notification entry held inside [FakeNotificationGateway].
class FakeScheduledNotification {
  /// Original schedule request passed to [FakeNotificationGateway.zonedSchedule].
  final ScheduledReminderRequest request;

  /// Whether exact scheduling mode was selected.
  final bool exact;

  /// Creates a [FakeScheduledNotification].
  const FakeScheduledNotification({required this.request, required this.exact});
}

/// Stateful in-memory [NotificationGateway] for deterministic off-device tests.
class FakeNotificationGateway implements NotificationGateway {
  /// Pending notifications indexed by deterministic notification ID.
  final Map<int, FakeScheduledNotification> scheduled =
      <int, FakeScheduledNotification>{};

  /// Ordered log of cancelled notification IDs.
  final List<int> cancelledIds = <int>[];

  /// Number of [cancelAll] invocations.
  int cancelAllCount = 0;

  /// Number of [initialize] invocations.
  int initializeCount = 0;

  /// Number of [zonedSchedule] invocations.
  int scheduleCallCount = 0;

  /// Number of [openSystemNotificationSettings] invocations.
  int openSettingsCallCount = 0;

  /// Local IANA timezone identifier returned by [resolveLocalTimezone].
  String timezoneIdentifier;

  /// Configurable permission status returned by [permissionStatus].
  NotificationPermissionStatus currentPermissionStatus;

  /// Optional launch event returned by [getLaunchEvent].
  NotificationTapEvent? launchEvent;

  /// Result returned by [requestNotificationsPermission].
  bool requestNotificationsResult;

  /// Result returned by [requestExactAlarmsPermission].
  bool requestExactAlarmsResult;

  /// Result returned by [openSystemNotificationSettings].
  bool openSettingsResult;

  final StreamController<NotificationTapEvent> _responsesController =
      StreamController<NotificationTapEvent>.broadcast();

  /// Creates an in-memory [FakeNotificationGateway].
  FakeNotificationGateway({
    this.timezoneIdentifier = 'UTC',
    this.currentPermissionStatus = const NotificationPermissionStatus(
      notificationsEnabled: true,
      exactAlarmsAllowed: false,
    ),
    this.launchEvent,
    this.requestNotificationsResult = true,
    this.requestExactAlarmsResult = true,
    this.openSettingsResult = true,
  });

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<String> resolveLocalTimezone() async {
    return timezoneIdentifier;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    return currentPermissionStatus;
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    currentPermissionStatus = currentPermissionStatus.copyWith(
      notificationsEnabled: requestNotificationsResult,
    );
    return requestNotificationsResult;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    currentPermissionStatus = currentPermissionStatus.copyWith(
      exactAlarmsAllowed: requestExactAlarmsResult,
    );
    return requestExactAlarmsResult;
  }

  @override
  Future<bool> openSystemNotificationSettings() async {
    openSettingsCallCount++;
    return openSettingsResult;
  }

  @override
  Future<void> zonedSchedule(
    ScheduledReminderRequest request, {
    bool exact = false,
  }) async {
    scheduleCallCount++;
    scheduled[request.notificationId] = FakeScheduledNotification(
      request: request,
      exact: exact,
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<List<int>> pendingNotificationIds() async {
    return scheduled.keys.toList();
  }

  @override
  Future<NotificationTapEvent?> getLaunchEvent() async {
    return launchEvent;
  }

  @override
  Stream<NotificationTapEvent> get responses => _responsesController.stream;

  /// Simulates a user tapping a notification or shade action in tests.
  void emitResponse(NotificationTapEvent event) {
    if (!_responsesController.isClosed) {
      _responsesController.add(event);
    }
  }

  /// Releases the internal broadcast stream controller.
  Future<void> dispose() async {
    await _responsesController.close();
  }
}
