import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/core/notifications/deterministic_id.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/data/database_service.dart';
import 'package:wyrm_desk/data/repositories/reminder_repository.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_coordinator.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/native/alarm_audio_gateway.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/fake_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/fln_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

class FakeClock extends Clock {
  DateTime _now;

  FakeClock(this._now) : super();

  @override
  DateTime now() => _now;

  void setTime(DateTime next) {
    _now = next;
  }

  void advance(Duration delta) {
    _now = _now.add(delta);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wyrm_rem_state_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return tempDir.path;
        });
  });

  tearDown(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer createContainer({
    required FakeClock clock,
    required FakeNotificationGateway notificationGateway,
    required FakeAlarmAudioGateway alarmAudioGateway,
    required StreamController<DateTime> tickController,
  }) {
    return ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        clockTimeProvider.overrideWith((ref) => tickController.stream),
        notificationGatewayProvider.overrideWithValue(notificationGateway),
        alarmAudioGatewayProvider.overrideWithValue(alarmAudioGateway),
      ],
    );
  }

  group('RemindersState helpers & value semantics', () {
    test('computes enabledItems, nextUpcoming, and sorted filteredItems', () {
      final now = DateTime(2026, 6, 15, 8, 0);
      final laterOnce = ReminderItem(
        id: 'rem-later',
        title: 'Afternoon tea',
        scheduledAt: DateTime(2026, 6, 15, 15, 0),
        recurrence: ReminderRecurrence.once,
        createdAt: now,
      );
      final soonDaily = ReminderItem(
        id: 'rem-soon',
        title: 'Stand up',
        scheduledAt: DateTime(2026, 6, 1, 9, 0),
        recurrence: ReminderRecurrence.daily,
        createdAt: now,
      );
      final pausedDaily = ReminderItem(
        id: 'rem-paused',
        title: 'Paused',
        scheduledAt: DateTime(2026, 6, 1, 8, 15),
        recurrence: ReminderRecurrence.daily,
        isEnabled: false,
        createdAt: now,
      );

      final state = RemindersState(
        items: [laterOnce, pausedDaily, soonDaily],
        isLoaded: true,
        permissions: const NotificationPermissionStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
        ),
      );

      expect(state.enabledItems, [laterOnce, soonDaily]);
      expect(state.nextUpcoming(now), soonDaily);
      expect(state.nextFireAtFor(soonDaily, now), DateTime(2026, 6, 15, 9, 0));
      expect(state.filteredItems(now), [soonDaily, laterOnce, pausedDaily]);

      final activeOnly = state.copyWith(filter: ReminderFilter.active);
      expect(activeOnly.filteredItems(now), [soonDaily, laterOnce]);

      final recurringOnly = state.copyWith(filter: ReminderFilter.recurring);
      expect(recurringOnly.filteredItems(now), [soonDaily, pausedDaily]);

      expect(
        state,
        RemindersState(
          items: [laterOnce, pausedDaily, soonDaily],
          isLoaded: true,
          permissions: const NotificationPermissionStatus(
            notificationsEnabled: true,
            exactAlarmsAllowed: true,
          ),
        ),
      );
      expect(
        state.hashCode,
        RemindersState(
          items: [laterOnce, pausedDaily, soonDaily],
          isLoaded: true,
          permissions: const NotificationPermissionStatus(
            notificationsEnabled: true,
            exactAlarmsAllowed: true,
          ),
        ).hashCode,
      );
    });
  });

  group('RemindersNotifier CRUD, permissions & OS sync', () {
    test('supports add, edit, toggle, delete, and permission sync', () async {
      final clock = FakeClock(DateTime(2026, 6, 15, 8, 0));
      final gateway = FakeNotificationGateway(
        currentPermissionStatus: const NotificationPermissionStatus(
          notificationsEnabled: false,
          exactAlarmsAllowed: false,
        ),
      );
      final audio = FakeAlarmAudioGateway();
      final ticks = StreamController<DateTime>.broadcast();

      final container = createContainer(
        clock: clock,
        notificationGateway: gateway,
        alarmAudioGateway: audio,
        tickController: ticks,
      );
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
        await ticks.close();
      });

      final notifier = container.read(remindersProvider.notifier);
      await notifier.initialized;
      expect(container.read(remindersProvider).isLoaded, isTrue);

      final first = await notifier.addReminder(
        title: '  Hydrate  ',
        scheduledAt: DateTime(2026, 6, 15, 9, 0),
      );
      final second = await notifier.addReminder(
        title: 'Standup',
        scheduledAt: DateTime(2026, 6, 15, 10, 0),
        recurrence: ReminderRecurrence.weekdays,
      );

      expect(first.id, isNot(second.id));
      expect(first.title, 'Hydrate');
      expect(container.read(remindersProvider).items, [first, second]);

      final firstInitialNotifId = deterministicNotificationId(
        first.id,
        first.scheduledAt,
      );
      expect(gateway.scheduled.containsKey(firstInitialNotifId), isTrue);
      expect(gateway.scheduled[firstInitialNotifId]!.exact, isFalse);

      // Edit first reminder's target time -> old ID cancelled, new ID scheduled.
      final editedFirst = first.copyWith(
        title: 'Hydrate & stretch',
        scheduledAt: DateTime(2026, 6, 15, 9, 30),
      );
      await notifier.editReminder(editedFirst);
      final editedNotifId = deterministicNotificationId(
        first.id,
        editedFirst.scheduledAt,
      );
      expect(gateway.cancelledIds, contains(firstInitialNotifId));
      expect(gateway.scheduled.containsKey(editedNotifId), isTrue);

      // Toggle disabled -> removes pending notification; re-enable restores it.
      await notifier.toggleReminder(first.id, false);
      expect(
        container
            .read(remindersProvider)
            .items
            .firstWhere((r) => r.id == first.id)
            .isEnabled,
        isFalse,
      );
      expect(gateway.scheduled.containsKey(editedNotifId), isFalse);

      await notifier.toggleReminder(first.id);
      expect(
        container
            .read(remindersProvider)
            .items
            .firstWhere((r) => r.id == first.id)
            .isEnabled,
        isTrue,
      );
      expect(gateway.scheduled.containsKey(editedNotifId), isTrue);

      // Granting permissions upgrades pending notifications to exact mode.
      expect(await notifier.requestNotificationsPermission(), isTrue);
      expect(await notifier.requestExactAlarmsPermission(), isTrue);
      expect(
        container.read(remindersProvider).permissions,
        const NotificationPermissionStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
        ),
      );
      expect(gateway.scheduled[editedNotifId]!.exact, isTrue);

      expect(await notifier.openSystemNotificationSettings(), isTrue);
      expect(gateway.openSettingsCallCount, 1);

      // Delete first -> persisted on disk and cancelled in OS gateway.
      await notifier.deleteReminder(first.id);
      expect(container.read(remindersProvider).items, [second]);
      expect(gateway.scheduled.containsKey(editedNotifId), isFalse);

      final persisted = await container
          .read(reminderRepositoryProvider)
          .loadReminders();
      expect(persisted, [second]);
    });
  });

  group('ActiveAlarmNotifier', () {
    test(
      'toJson, equality, and preview alarm isolation without mutating state',
      () async {
        final clock = FakeClock(DateTime(2026, 6, 15, 8, 0));
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final ticks = StreamController<DateTime>.broadcast();

        final container = createContainer(
          clock: clock,
          notificationGateway: gateway,
          alarmAudioGateway: audio,
          tickController: ticks,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
          await ticks.close();
        });

        final notifier = container.read(remindersProvider.notifier);
        await notifier.initialized;
        final item = await notifier.addReminder(
          title: 'Take vitamins',
          scheduledAt: DateTime(2026, 6, 15, 9, 0),
        );

        final firedAt = DateTime(2026, 6, 15, 8, 5);
        final activeNotifier = container.read(activeAlarmProvider.notifier);
        await activeNotifier.triggerAlarm(item, firedAt, isPreview: true);

        final activeState = container.read(activeAlarmProvider)!;
        expect(activeState.isPreview, isTrue);
        expect(activeState.toJson(), <String, dynamic>{
          'reminder': item.toJson(),
          'fired_at': firedAt.toIso8601String(),
          'is_preview': true,
        });
        expect(
          activeState,
          ActiveAlarmState(reminder: item, firedAt: firedAt, isPreview: true),
        );
        expect(audio.isPlaying, isTrue);
        expect(audio.wakeScreenEnabled, isTrue);
        expect(audio.startCount, 1);

        // Duplicate trigger for exact same occurrence is ignored.
        await activeNotifier.triggerAlarm(item, firedAt, isPreview: true);
        expect(audio.startCount, 1);

        // Dismissing preview stops chime & clears wake screen, keeps reminder intact.
        await activeNotifier.dismissActive();
        expect(container.read(activeAlarmProvider), isNull);
        expect(audio.isPlaying, isFalse);
        expect(audio.wakeScreenEnabled, isFalse);
        expect(audio.stopCount, 1);
        expect(container.read(remindersProvider).items.single, item);
      },
    );
  });

  group('ReminderCoordinator triggers, dismiss & snooze', () {
    test('clock tick reaching target marks triggered before raising alarm and avoids double-fire', () async {
      final clock = FakeClock(DateTime(2026, 6, 15, 8, 59, 58));
      final gateway = FakeNotificationGateway();
      final audio = FakeAlarmAudioGateway();
      final ticks = StreamController<DateTime>.broadcast();

      final container = createContainer(
        clock: clock,
        notificationGateway: gateway,
        alarmAudioGateway: audio,
        tickController: ticks,
      );
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
        await ticks.close();
      });

      final coordinator = container.read(reminderCoordinatorProvider);
      await coordinator.initialized;

      final notifier = container.read(remindersProvider.notifier);
      await notifier.initialized;
      final target = DateTime(2026, 6, 15, 9, 0);
      final item = await notifier.addReminder(
        title: 'Team standup',
        scheduledAt: target,
        recurrence: ReminderRecurrence.once,
      );

      var triggeredBeforeAlarm = false;
      container.listen<ActiveAlarmState?>(activeAlarmProvider, (prev, next) {
        if (next != null) {
          final latest = container
              .read(remindersProvider)
              .items
              .firstWhere((r) => r.id == item.id);
          triggeredBeforeAlarm = latest.lastTriggeredAt == target;
        }
      });

      // Tick 1 second before target -> nothing fires.
      clock.setTime(DateTime(2026, 6, 15, 8, 59, 59));
      ticks.add(clock.now());
      await pumpEventQueue();
      expect(container.read(activeAlarmProvider), isNull);
      expect(audio.isPlaying, isFalse);

      // Tick exactly at target -> marks triggered first, triggers alarm & chime.
      clock.setTime(target);
      ticks.add(target);
      await pumpEventQueue();

      expect(triggeredBeforeAlarm, isTrue);
      final active = container.read(activeAlarmProvider);
      expect(active, isNotNull);
      expect(active!.reminder.id, item.id);
      expect(active.firedAt, target);
      expect(audio.isPlaying, isTrue);
      expect(audio.wakeScreenEnabled, isTrue);
      expect(audio.startCount, 1);

      // Subsequent 1s ticks must never double-fire.
      clock.setTime(target.add(const Duration(seconds: 1)));
      ticks.add(clock.now());
      await pumpEventQueue();
      expect(audio.startCount, 1);

      // Dismiss once reminder -> stops audio, disables item, keeps lastTriggeredAt.
      await container.read(activeAlarmProvider.notifier).dismissActive();
      expect(container.read(activeAlarmProvider), isNull);
      expect(audio.isPlaying, isFalse);
      expect(audio.wakeScreenEnabled, isFalse);

      final updated = container.read(remindersProvider).items.single;
      expect(updated.isEnabled, isFalse);
      expect(updated.snoozedUntil, isNull);
      expect(updated.lastTriggeredAt, target);

      // Even another tick after dismissal does not re-fire once reminder.
      clock.setTime(target.add(const Duration(seconds: 5)));
      ticks.add(clock.now());
      await pumpEventQueue();
      expect(container.read(activeAlarmProvider), isNull);
      expect(audio.startCount, 1);
    });

    test('repeating dismiss keeps enabled for tomorrow and snooze +10m re-triggers cleanly', () async {
      final clock = FakeClock(DateTime(2026, 6, 15, 7, 59));
      final gateway = FakeNotificationGateway();
      final audio = FakeAlarmAudioGateway();
      final ticks = StreamController<DateTime>.broadcast();

      final container = createContainer(
        clock: clock,
        notificationGateway: gateway,
        alarmAudioGateway: audio,
        tickController: ticks,
      );
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
        await ticks.close();
      });

      final coordinator = container.read(reminderCoordinatorProvider);
      await coordinator.initialized;

      final notifier = container.read(remindersProvider.notifier);
      await notifier.initialized;

      final dailyTarget = DateTime(2026, 6, 15, 8, 0);
      final daily = await notifier.addReminder(
        title: 'Morning stretch',
        scheduledAt: dailyTarget,
        recurrence: ReminderRecurrence.daily,
      );

      // Fire at 08:00.
      clock.setTime(dailyTarget);
      await coordinator.evaluateDueReminders(dailyTarget);
      expect(container.read(activeAlarmProvider)?.reminder.id, daily.id);
      expect(audio.startCount, 1);

      // Snooze +10m at 08:00:15 -> stops audio, schedules 08:10:15 snooze.
      final snoozedAt = DateTime(2026, 6, 15, 8, 0, 15);
      final expectedSnoozeTarget = snoozedAt.add(const Duration(minutes: 10));
      clock.setTime(snoozedAt);
      await container.read(activeAlarmProvider.notifier).snoozeActive();

      expect(container.read(activeAlarmProvider), isNull);
      expect(audio.isPlaying, isFalse);
      expect(audio.wakeScreenEnabled, isFalse);

      final snoozedItem = container.read(remindersProvider).items.single;
      expect(snoozedItem.isEnabled, isTrue);
      expect(snoozedItem.snoozedUntil, expectedSnoozeTarget);
      expect(
        gateway.scheduled.containsKey(
          deterministicNotificationId(daily.id, expectedSnoozeTarget),
        ),
        isTrue,
      );

      // Tick at +5m -> still snoozed.
      clock.setTime(snoozedAt.add(const Duration(minutes: 5)));
      ticks.add(clock.now());
      await pumpEventQueue();
      expect(container.read(activeAlarmProvider), isNull);

      // Tick at +10m -> snoozed occurrence re-triggers.
      clock.setTime(expectedSnoozeTarget);
      ticks.add(expectedSnoozeTarget);
      await pumpEventQueue();
      expect(
        container.read(activeAlarmProvider)?.firedAt,
        expectedSnoozeTarget,
      );
      expect(audio.isPlaying, isTrue);
      expect(audio.startCount, 2);

      // Dismiss repeating reminder -> stays enabled, clears snooze, schedules tomorrow.
      await container.read(activeAlarmProvider.notifier).dismissActive();
      final afterDismiss = container.read(remindersProvider).items.single;
      expect(afterDismiss.isEnabled, isTrue);
      expect(afterDismiss.snoozedUntil, isNull);
      expect(afterDismiss.lastTriggeredAt, expectedSnoozeTarget);
      expect(
        container
            .read(remindersProvider)
            .nextFireAtFor(afterDismiss, expectedSnoozeTarget),
        DateTime(2026, 6, 16, 8, 0),
      );
    });
  });

  group('Shade actions, launch payload, lifecycle & backup reload', () {
    test('handles shade dismiss, shade snooze, body tap, launch event, resume, and dispose', () async {
      final baseTime = DateTime(2026, 6, 15, 9, 0);
      final clock = FakeClock(baseTime);
      final futureTarget = DateTime(2026, 6, 15, 11, 0);
      final seeded = ReminderItem(
        id: 'rem-launch',
        title: 'Launch check',
        scheduledAt: futureTarget,
        recurrence: ReminderRecurrence.daily,
        createdAt: DateTime(2026, 6, 14, 9, 0),
      );

      // Persist reminder before container boots to test cold-launch payload.
      await AppDatabase.writeSection('reminders', [seeded.toJson()]);

      final launchNotifId = deterministicNotificationId(
        seeded.id,
        futureTarget,
      );
      final gateway = FakeNotificationGateway(
        launchEvent: NotificationTapEvent(
          actionId: null,
          notificationId: launchNotifId,
          payload: jsonEncode(<String, dynamic>{
            'reminder_id': seeded.id,
            'occurrence_epoch_ms': futureTarget.millisecondsSinceEpoch,
          }),
        ),
      );
      final audio = FakeAlarmAudioGateway();
      final ticks = StreamController<DateTime>.broadcast();

      final container = createContainer(
        clock: clock,
        notificationGateway: gateway,
        alarmAudioGateway: audio,
        tickController: ticks,
      );
      var isDisposed = false;
      addTearDown(() async {
        if (!isDisposed) {
          container.dispose();
        }
        await gateway.dispose();
        await ticks.close();
      });

      final coordinator = container.read(reminderCoordinatorProvider);
      await coordinator.initialized;
      await pumpEventQueue();

      // Launch body tap waited for disk hydration and raised active alarm.
      expect(container.read(activeAlarmProvider)?.reminder.id, seeded.id);
      expect(audio.isPlaying, isTrue);
      expect(gateway.cancelledIds, contains(launchNotifId));

      // Shade snooze action clears active alarm and snoozes +10m.
      gateway.emitResponse(
        NotificationTapEvent(
          actionId: FlnNotificationGateway.actionSnoozeId,
          notificationId: launchNotifId,
          payload: jsonEncode(<String, dynamic>{
            'reminder_id': seeded.id,
            'occurrence_epoch_ms': futureTarget.millisecondsSinceEpoch,
          }),
        ),
      );
      await pumpEventQueue();
      expect(container.read(activeAlarmProvider), isNull);
      expect(audio.isPlaying, isFalse);
      final afterShadeSnooze = container.read(remindersProvider).items.single;
      expect(
        afterShadeSnooze.snoozedUntil,
        baseTime.add(const Duration(minutes: 10)),
      );

      // Shade dismiss action cancels snooze and marks occurrence dismissed.
      gateway.emitResponse(
        NotificationTapEvent(
          actionId: FlnNotificationGateway.actionDismissId,
          notificationId: 99,
          payload: jsonEncode(<String, dynamic>{
            'reminder_id': seeded.id,
            'occurrence_epoch_ms': futureTarget.millisecondsSinceEpoch,
          }),
        ),
      );
      await pumpEventQueue();
      final afterShadeDismiss = container.read(remindersProvider).items.single;
      expect(afterShadeDismiss.isEnabled, isTrue);
      expect(afterShadeDismiss.snoozedUntil, isNull);
      expect(afterShadeDismiss.lastTriggeredAt, futureTarget);
      expect(gateway.cancelledIds, contains(99));

      // Lifecycle resume refreshes timezone, permissions, missed alarms, & resyncs.
      final missedOnce = ReminderItem(
        id: 'rem-missed',
        title: 'Missed on resume',
        scheduledAt: DateTime(2026, 6, 15, 9, 5),
        recurrence: ReminderRecurrence.once,
        createdAt: baseTime,
      );
      await container
          .read(remindersProvider.notifier)
          .addExistingReminder(missedOnce);

      clock.setTime(DateTime(2026, 6, 15, 9, 6));
      gateway.timezoneIdentifier = 'America/New_York';
      gateway.currentPermissionStatus = const NotificationPermissionStatus(
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
      );
      final scheduleCallsBeforeResume = gateway.scheduleCallCount;

      await coordinator.handleAppResumed();

      expect(
        container.read(remindersProvider).permissions.exactAlarmsAllowed,
        isTrue,
      );
      expect(container.read(activeAlarmProvider)?.reminder.id, missedOnce.id);
      expect(gateway.scheduleCallCount, greaterThan(scheduleCallsBeforeResume));

      // Dispose cancels subscriptions cleanly without dangling listeners.
      container.dispose();
      isDisposed = true;
      gateway.emitResponse(
        NotificationTapEvent(
          actionId: null,
          payload: jsonEncode(<String, dynamic>{'reminder_id': seeded.id}),
        ),
      );
      await pumpEventQueue();
    });

    test('DatabaseService.reloadAllState reloads reminders and rebuilds OS notifications', () async {
      final clock = FakeClock(DateTime(2026, 6, 15, 8, 0));
      final gateway = FakeNotificationGateway(
        currentPermissionStatus: const NotificationPermissionStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
        ),
      );
      final audio = FakeAlarmAudioGateway();
      final ticks = StreamController<DateTime>.broadcast();

      final container = createContainer(
        clock: clock,
        notificationGateway: gateway,
        alarmAudioGateway: audio,
        tickController: ticks,
      );
      addTearDown(() async {
        container.dispose();
        await gateway.dispose();
        await ticks.close();
      });

      final notifier = container.read(remindersProvider.notifier);
      await notifier.initialized;
      final initial = await notifier.addReminder(
        title: 'Before restore',
        scheduledAt: DateTime(2026, 6, 15, 9, 0),
      );
      final staleId = deterministicNotificationId(
        initial.id,
        initial.scheduledAt,
      );
      expect(gateway.scheduled.containsKey(staleId), isTrue);

      // Import a backup containing a completely different reminder set.
      final restoredItem = ReminderItem(
        id: 'restored-1',
        title: 'Restored alarm',
        scheduledAt: DateTime(2026, 6, 15, 11, 30),
        recurrence: ReminderRecurrence.once,
        createdAt: DateTime(2026, 6, 15, 7, 0),
      );
      final backupJson = jsonEncode(<String, dynamic>{
        'version': 1,
        'reminders': [restoredItem.toJson()],
      });
      expect(await AppDatabase.importDatabaseJson(backupJson), isTrue);

      await container.read(databaseServiceProvider).reloadAllState();

      expect(container.read(remindersProvider).items, [restoredItem]);
      expect(gateway.cancelAllCount, greaterThanOrEqualTo(1));
      expect(gateway.scheduled.containsKey(staleId), isFalse);
      expect(
        gateway.scheduled.containsKey(
          deterministicNotificationId(
            restoredItem.id,
            restoredItem.scheduledAt,
          ),
        ),
        isTrue,
      );
    });
  });
}
