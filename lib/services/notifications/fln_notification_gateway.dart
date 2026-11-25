import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

/// Top-level background notification action handler invoked in a headless
/// isolate when a user taps a shade action (`Cancel` / `Snooze 10m`) with
/// `showsUserInterface: false`.
@pragma('vm:entry-point')
Future<void> wyrmNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {
    // Ignore when already bound or running under a non-widget test harness.
  }
  final gateway = FlnNotificationGateway();
  try {
    await gateway.resolveLocalTimezone();
    await handleNotificationShadeAction(
      actionId: response.actionId,
      payload: response.payload,
      notificationId: response.id,
      gateway: gateway,
    );
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        '[FlnNotificationGateway] background action handler failed: $error',
      );
    }
  } finally {
    await gateway.dispose();
  }
}

/// Applies a shade action (`dismiss` or `snooze`) directly to the persisted
/// `'reminders'` section in [AppDatabase] and reconciles OS alarms via
/// [syncNotifications].
///
/// Exposed for deterministic off-device testing alongside [wyrmNotificationBackgroundHandler].
Future<void> handleNotificationShadeAction({
  required String? actionId,
  required String? payload,
  int? notificationId,
  required NotificationGateway gateway,
  Clock clock = const Clock(),
}) async {
  final event = NotificationTapEvent(
    actionId: actionId,
    payload: payload,
    notificationId: notificationId,
  );
  final reminderId = event.reminderId;
  final now = clock.now();
  final firedAt = event.occurrenceAt ?? now;

  if (reminderId != null &&
      (actionId == FlnNotificationGateway.actionDismissId ||
          actionId == FlnNotificationGateway.actionSnoozeId)) {
    AppDatabase.invalidateCache();
    final raw = await AppDatabase.readSection('reminders', forceRefresh: true);
    final reminders = raw is List
        ? raw
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (entry) =>
                    ReminderItem.fromJson(Map<String, dynamic>.from(entry)),
              )
              .toList()
        : <ReminderItem>[];

    var changed = false;
    final updated = reminders.map((item) {
      if (item.id != reminderId) return item;
      changed = true;
      if (actionId == FlnNotificationGateway.actionDismissId) {
        return item.copyWith(
          isEnabled: item.recurrence == ReminderRecurrence.once
              ? false
              : item.isEnabled,
          clearSnoozedUntil: true,
          lastTriggeredAt: firedAt,
        );
      }
      return item.copyWith(
        isEnabled: true,
        snoozedUntil: now.add(FlnNotificationGateway.defaultSnoozeDuration),
        lastTriggeredAt: firedAt,
      );
    }).toList();

    if (changed) {
      await AppDatabase.writeSection(
        'reminders',
        updated.map((r) => r.toJson()).toList(),
      );
    }
    if (notificationId != null) {
      await gateway.cancel(notificationId);
    }
    await syncNotifications(gateway: gateway, reminders: updated, now: now);
    return;
  }

  if (notificationId != null) {
    await gateway.cancel(notificationId);
  }
}

/// Concrete [NotificationGateway] backed by `flutter_local_notifications`,
/// `timezone`, and `flutter_timezone`.
///
/// This is the ONLY file in the repository permitted to import those packages.
class FlnNotificationGateway implements NotificationGateway {
  /// Dedicated Android notification channel ID for high-priority reminder alarms.
  static const String alarmChannelId = 'wyrm_reminders_alarm';

  /// User-visible Android notification channel name.
  static const String alarmChannelName = 'Reminders & Alarms';

  /// User-visible Android notification channel description.
  static const String alarmChannelDescription =
      'Full-screen alarm alerts for scheduled reminders';

  /// Shade action identifier to dismiss/cancel a ringing reminder.
  static const String actionDismissId = 'dismiss';

  /// Shade action identifier to snooze a ringing reminder for 10 minutes.
  static const String actionSnoozeId = 'snooze';

  /// Default duration applied by the shade snooze action.
  static const Duration defaultSnoozeDuration = Duration(minutes: 10);

  static const String _androidDefaultIcon = 'ic_launcher_monochrome';
  static const String _darwinCategoryId = 'wyrm_reminders_category';

  static bool _tzDatabaseInitialized = false;

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTapEvent> _responsesController =
      StreamController<NotificationTapEvent>.broadcast();

  bool _initialized = false;
  Future<void>? _initializing;

  /// Creates an [FlnNotificationGateway].
  FlnNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  void _ensureTimeZonesInitialized() {
    if (_tzDatabaseInitialized) return;
    try {
      tz_data.initializeTimeZones();
      _tzDatabaseInitialized = true;
    } catch (_) {
      // Leave false so a future retry can attempt initialization if needed.
    }
  }

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final existing = _initializing;
    if (existing != null) return existing;

    final future = _performInitialize();
    _initializing = future;
    return future;
  }

  Future<void> _performInitialize() async {
    try {
      _ensureTimeZonesInitialized();
      await resolveLocalTimezone();

      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _darwinCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(actionDismissId, 'Cancel'),
              DarwinNotificationAction.plain(actionSnoozeId, 'Snooze 10m'),
            ],
          ),
        ],
      );

      final settings = InitializationSettings(
        android: const AndroidInitializationSettings(_androidDefaultIcon),
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: const LinuxInitializationSettings(
          defaultActionName: 'Open reminder',
        ),
        windows: const WindowsInitializationSettings(
          appName: 'Wyrm Desk',
          appUserModelId: 'com.jdmakes.wyrm',
          guid: 'a8a2b86d-4b23-4c9a-9f5b-6e8b9a3d1c2e',
        ),
      );

      await _safePluginCall<void>(() async {
        await _plugin.initialize(
          settings: settings,
          onDidReceiveNotificationResponse: _onNotificationResponse,
          onDidReceiveBackgroundNotificationResponse:
              wyrmNotificationBackgroundHandler,
        );

        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            alarmChannelId,
            alarmChannelName,
            description: alarmChannelDescription,
            importance: Importance.max,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }, fallback: null);

      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (_responsesController.isClosed) return;
    _responsesController.add(
      NotificationTapEvent(
        actionId: response.actionId,
        payload: response.payload,
        notificationId: response.id,
      ),
    );
  }

  @override
  Future<String> resolveLocalTimezone() async {
    _ensureTimeZonesInitialized();
    return _safePluginCall<String>(() async {
      final info = await FlutterTimezone.getLocalTimezone();
      final identifier = info.identifier.trim();
      if (identifier.isEmpty) {
        tz.setLocalLocation(tz.UTC);
        return 'UTC';
      }
      final location = tz.getLocation(identifier);
      tz.setLocalLocation(location);
      return identifier;
    }, fallback: _fallbackUtcTimezone());
  }

  String _fallbackUtcTimezone() {
    try {
      tz.setLocalLocation(tz.UTC);
    } catch (_) {
      // Ignored when tz database failed to initialize.
    }
    return 'UTC';
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    if (kIsWeb) {
      return const NotificationPermissionStatus();
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _safePluginCall<NotificationPermissionStatus>(() async {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final notificationsEnabled =
            await android?.areNotificationsEnabled() ?? false;
        final exactAllowed =
            await android?.canScheduleExactNotifications() ?? false;
        return NotificationPermissionStatus(
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
        );
      }, fallback: const NotificationPermissionStatus());
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _safePluginCall<NotificationPermissionStatus>(() async {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final options = await ios?.checkPermissions();
        return NotificationPermissionStatus(
          notificationsEnabled: options?.isEnabled ?? false,
          exactAlarmsAllowed: options?.isEnabled ?? false,
        );
      }, fallback: const NotificationPermissionStatus());
    }
    return const NotificationPermissionStatus();
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _safePluginCall<bool>(() async {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }, fallback: false);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _safePluginCall<bool>(() async {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }, fallback: false);
    }
    return false;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return _safePluginCall<bool>(() async {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestExactAlarmsPermission() ?? false;
    }, fallback: false);
  }

  @override
  Future<bool> openSystemNotificationSettings() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _safePluginCall<bool>(() async {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final enabled = await android?.areNotificationsEnabled() ?? false;
        if (!enabled) {
          return await android?.requestNotificationsPermission() ?? false;
        }
        return await android?.requestExactAlarmsPermission() ?? false;
      }, fallback: false);
    }
    return false;
  }

  @override
  Future<void> zonedSchedule(
    ScheduledReminderRequest request, {
    bool exact = false,
  }) async {
    _ensureTimeZonesInitialized();
    if (!_initialized) {
      await initialize();
    }

    await _safePluginCall<void>(() async {
      final scheduledDate = tz.TZDateTime.from(request.fireAt, tz.local);
      final details = NotificationDetails(
        android: const AndroidNotificationDetails(
          alarmChannelId,
          alarmChannelName,
          channelDescription: alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          autoCancel: true,
          visibility: NotificationVisibility.public,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              actionDismissId,
              'Cancel',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              actionSnoozeId,
              'Snooze 10m',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          categoryIdentifier: _darwinCategoryId,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          categoryIdentifier: _darwinCategoryId,
        ),
      );

      await _plugin.zonedSchedule(
        id: request.notificationId,
        title: request.title,
        body: request.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: request.payloadJson,
      );
    }, fallback: null);
  }

  @override
  Future<void> cancel(int id) async {
    await _safePluginCall<void>(() async {
      await _plugin.cancel(id: id);
    }, fallback: null);
  }

  @override
  Future<void> cancelAll() async {
    await _safePluginCall<void>(() async {
      await _plugin.cancelAll();
    }, fallback: null);
  }

  @override
  Future<List<int>> pendingNotificationIds() async {
    return _safePluginCall<List<int>>(() async {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.map((item) => item.id).toList();
    }, fallback: const <int>[]);
  }

  @override
  Future<NotificationTapEvent?> getLaunchEvent() async {
    return _safePluginCall<NotificationTapEvent?>(() async {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) {
        return null;
      }
      final response = details.notificationResponse;
      return NotificationTapEvent(
        actionId: response?.actionId,
        payload: response?.payload,
        notificationId: response?.id,
      );
    }, fallback: null);
  }

  @override
  Stream<NotificationTapEvent> get responses => _responsesController.stream;

  /// Releases the internal stream controller.
  Future<void> dispose() async {
    if (!_responsesController.isClosed) {
      await _responsesController.close();
    }
  }

  Future<T> _safePluginCall<T>(
    Future<T> Function() action, {
    required T fallback,
  }) async {
    try {
      return await action();
    } on MissingPluginException {
      return fallback;
    } on PlatformException {
      return fallback;
    } on UnimplementedError {
      return fallback;
    } on UnsupportedError {
      return fallback;
    } catch (error) {
      if (kDebugMode &&
          !error.toString().contains('has not been initialized')) {
        debugPrint('[FlnNotificationGateway] plugin call ignored: $error');
      }
      return fallback;
    }
  }
}
