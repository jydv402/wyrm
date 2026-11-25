import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/fln_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

/// Root coordinator bridging live clock ticks, notification gateway actions,
/// app lifecycle resume, and the active alarm overlay.
class ReminderCoordinator {
  final Ref _ref;

  StreamSubscription<NotificationTapEvent>? _responsesSub;
  ProviderSubscription<AsyncValue<DateTime>>? _clockSub;
  AppLifecycleListener? _lifecycleListener;
  Future<void> _initFuture = Future<void>.value();
  String? _lastTimezone;
  bool _disposed = false;
  bool _isEvaluatingDue = false;

  /// Creates and boots a [ReminderCoordinator] bound to [_ref].
  ReminderCoordinator(this._ref) {
    _start();
  }

  /// Completes once initial gateway setup and cold-launch payload handling run.
  Future<void> get initialized => _initFuture;

  NotificationGateway get _gateway => _ref.read(notificationGatewayProvider);
  Clock get _clock => _ref.read(clockProvider);

  /// Pure helper selecting the earliest due reminder at [now], or `null`.
  static ({ReminderItem item, DateTime dueAt})? findNextDueReminder(
    List<ReminderItem> items, {
    required DateTime now,
  }) {
    ReminderItem? bestItem;
    DateTime? bestDueAt;

    for (final item in items) {
      final dueAt = ReminderScheduler.currentDueOccurrence(item, now: now);
      if (dueAt == null) continue;
      if (bestDueAt == null ||
          dueAt.isBefore(bestDueAt) ||
          (dueAt.isAtSameMomentAs(bestDueAt) &&
              item.id.compareTo(bestItem!.id) < 0)) {
        bestItem = item;
        bestDueAt = dueAt;
      }
    }

    if (bestItem == null || bestDueAt == null) return null;
    return (item: bestItem, dueAt: bestDueAt);
  }

  void _start() {
    _responsesSub = _gateway.responses.listen(_handleNotificationEvent);

    try {
      _lifecycleListener = AppLifecycleListener(onResume: handleAppResumed);
    } catch (_) {
      // Safe fallback when instantiated outside a bound Flutter test/app host.
    }

    // Subscribe on the container rather than `ref.listen` so Riverpod 3's
    // auto-pause does not suspend `clockTimeProvider` when callers bootstrap the
    // coordinator via `container.read(reminderCoordinatorProvider)`.
    _clockSub = _ref.container.listen<AsyncValue<DateTime>>(clockTimeProvider, (
      previous,
      next,
    ) {
      final tickTime = next.value;
      if (tickTime != null) {
        unawaited(evaluateDueReminders(tickTime));
      }
    });

    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    await _gateway.initialize();
    if (_isStale) return;

    _lastTimezone = await _gateway.resolveLocalTimezone();
    if (_isStale) return;

    final launchEvent = await _gateway.getLaunchEvent();
    if (_isStale) return;

    if (launchEvent != null) {
      await _handleNotificationEvent(launchEvent);
    }
  }

  /// Refreshes timezone and permissions on app resume, reloads persisted
  /// reminders from disk (picking up background-isolate shade actions),
  /// evaluates any missed due occurrence, and reconciles OS schedules.
  Future<void> handleAppResumed() async {
    if (_isStale) return;

    final resolvedTimezone = await _gateway.resolveLocalTimezone();
    if (_isStale) return;

    final timezoneChanged =
        _lastTimezone != null && _lastTimezone != resolvedTimezone;
    _lastTimezone = resolvedTimezone;

    // Wait for initial load if still hydrating, then always reload fresh disk
    // state so background shade actions (Cancel / Snooze) are picked up.
    if (!_ref.read(remindersProvider).isLoaded) {
      await _ref.read(remindersProvider.notifier).initialized;
      if (_isStale) return;
    }

    await _ref.read(remindersProvider.notifier).reloadFromDisk();
    if (_isStale) return;

    final now = _clock.now();
    await evaluateDueReminders(now);
    if (_isStale) return;

    await syncNotifications(
      gateway: _gateway,
      reminders: _ref.read(remindersProvider).items,
      now: _clock.now(),
      forceReschedule: timezoneChanged,
    );
  }

  /// Evaluates loaded reminders against [tickTime] and triggers at most one due
  /// alarm when no alarm is currently ringing.
  Future<void> evaluateDueReminders(DateTime tickTime) async {
    if (_isStale || _isEvaluatingDue) return;

    final remindersState = _ref.read(remindersProvider);
    if (!remindersState.isLoaded) return;
    if (_ref.read(activeAlarmProvider) != null) return;

    final dueMatch = findNextDueReminder(remindersState.items, now: tickTime);
    if (dueMatch == null) return;

    _isEvaluatingDue = true;
    try {
      // Mark triggered synchronously before raising the alarm so subsequent 1s
      // ticks cannot double-fire the same occurrence.
      final markFuture = _ref
          .read(remindersProvider.notifier)
          .markTriggered(dueMatch.item.id, dueMatch.dueAt);

      final updatedItem =
          _findById(dueMatch.item.id) ??
          dueMatch.item.copyWith(lastTriggeredAt: dueMatch.dueAt);

      final alarmFuture = _ref
          .read(activeAlarmProvider.notifier)
          .triggerAlarm(updatedItem, dueMatch.dueAt);

      await Future.wait<void>(<Future<void>>[markFuture, alarmFuture]);
    } finally {
      _isEvaluatingDue = false;
    }
  }

  Future<void> _handleNotificationEvent(NotificationTapEvent event) async {
    if (_isStale) return;

    if (event.notificationId != null) {
      await _gateway.cancel(event.notificationId!);
      if (_isStale) return;
    }

    if (!_ref.read(remindersProvider).isLoaded) {
      await _ref.read(remindersProvider.notifier).initialized;
      if (_isStale) return;
    }

    final reminderId = event.reminderId;
    if (reminderId == null) return;

    final firedAt = event.occurrenceAt ?? _clock.now();
    final actionId = event.actionId?.trim();

    if (actionId == FlnNotificationGateway.actionDismissId) {
      final active = _ref.read(activeAlarmProvider);
      if (active != null && active.reminder.id == reminderId) {
        await _ref.read(activeAlarmProvider.notifier).dismissActive();
      } else {
        await _ref
            .read(remindersProvider.notifier)
            .dismissReminder(reminderId, firedAt: firedAt);
      }
      return;
    }

    if (actionId == FlnNotificationGateway.actionSnoozeId) {
      final active = _ref.read(activeAlarmProvider);
      if (active != null && active.reminder.id == reminderId) {
        await _ref
            .read(activeAlarmProvider.notifier)
            .snoozeActive(FlnNotificationGateway.defaultSnoozeDuration);
      } else {
        await _ref
            .read(remindersProvider.notifier)
            .snoozeReminder(
              reminderId,
              duration: FlnNotificationGateway.defaultSnoozeDuration,
            );
      }
      return;
    }

    final item = _findById(reminderId);
    if (item == null || !item.isEnabled) return;

    final markFuture = _ref
        .read(remindersProvider.notifier)
        .markTriggered(item.id, firedAt);
    final updatedItem = _findById(item.id) ?? item;
    final alarmFuture = _ref
        .read(activeAlarmProvider.notifier)
        .triggerAlarm(updatedItem, firedAt);

    await Future.wait<void>(<Future<void>>[markFuture, alarmFuture]);
  }

  ReminderItem? _findById(String id) {
    for (final item in _ref.read(remindersProvider).items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool get _isStale => _disposed || !_ref.mounted;

  /// Cancels notification stream listeners, clock subscription, and lifecycle
  /// hooks on disposal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clockSub?.close();
    _clockSub = null;
    unawaited(_responsesSub?.cancel());
    _responsesSub = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}

/// Root provider managing reminder alarm triggering, shade responses, and
/// lifecycle synchronization.
final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final coordinator = ReminderCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
