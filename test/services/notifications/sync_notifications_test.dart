import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/core/notifications/deterministic_id.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/data/repositories/repositories.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/fake_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/fln_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('syncNotifications & rebuildNotificationsAfterRestore', () {
    test('is idempotent on unchanged inputs and cancels stale on edit', () async {
      final now = DateTime(2026, 6, 15, 8, 0);
      final clock = Clock.fixed(now);
      final gateway = FakeNotificationGateway(
        currentPermissionStatus: const NotificationPermissionStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
        ),
      );
      addTearDown(gateway.dispose);

      final item = ReminderItem(
        id: 'rem-1',
        title: 'Stand up',
        scheduledAt: DateTime(2026, 6, 15, 9, 0),
        recurrence: ReminderRecurrence.once,
        createdAt: now,
      );

      await syncNotifications(
        gateway: gateway,
        reminders: [item],
        now: clock.now(),
      );

      final initialId = deterministicNotificationId('rem-1', item.scheduledAt);
      expect(gateway.scheduled.keys, [initialId]);
      expect(gateway.scheduled[initialId]!.exact, isTrue);
      expect(gateway.scheduleCallCount, 1);

      // Re-running with identical state must be a complete no-op.
      await syncNotifications(
        gateway: gateway,
        reminders: [item],
        now: clock.now(),
      );
      expect(gateway.scheduleCallCount, 1);
      expect(gateway.cancelledIds, isEmpty);

      // Editing fire time yields a new ID: old ID cancelled, new ID scheduled.
      final editedTime = DateTime(2026, 6, 15, 14, 0);
      final edited = item.copyWith(scheduledAt: editedTime);
      await syncNotifications(
        gateway: gateway,
        reminders: [edited],
        now: clock.now(),
      );
      final editedId = deterministicNotificationId('rem-1', editedTime);
      expect(gateway.cancelledIds, [initialId]);
      expect(gateway.scheduled.keys, [editedId]);
    });

    test('uses inexact mode when exactAlarmsAllowed is false', () async {
      final now = DateTime(2026, 6, 15, 8, 0);
      final gateway = FakeNotificationGateway(
        currentPermissionStatus: const NotificationPermissionStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: false,
        ),
      );
      addTearDown(gateway.dispose);

      final item = ReminderItem(
        id: 'rem-inexact',
        title: 'Tea break',
        scheduledAt: DateTime(2026, 6, 15, 16, 0),
        createdAt: now,
      );

      await syncNotifications(gateway: gateway, reminders: [item], now: now);
      final expectedId = deterministicNotificationId(
        'rem-inexact',
        item.scheduledAt,
      );
      expect(gateway.scheduled[expectedId]!.exact, isFalse);

      // Permission granted later -> forceReschedule upgrades pending entry.
      await gateway.requestExactAlarmsPermission();
      await syncNotifications(
        gateway: gateway,
        reminders: [item],
        now: now,
        forceReschedule: true,
      );
      expect(gateway.scheduled[expectedId]!.exact, isTrue);
    });

    test('enforces 48-slot OS cap and clears stale IDs on restore', () async {
      final now = DateTime(2026, 6, 15, 8, 0);
      final gateway = FakeNotificationGateway();
      addTearDown(gateway.dispose);

      // Seed an unrelated pre-restore ID that must be wiped by cancelAll().
      await syncNotifications(
        gateway: gateway,
        reminders: [
          ReminderItem(
            id: 'stale-before-restore',
            title: 'Old backup alarm',
            scheduledAt: DateTime(2026, 6, 15, 8, 30),
            createdAt: now,
          ),
        ],
        now: now,
      );
      final staleId = gateway.scheduled.keys.single;

      final restored = <ReminderItem>[
        for (var i = 1; i <= 70; i++)
          ReminderItem(
            id: 'restored-$i',
            title: 'Restored $i',
            scheduledAt: now.add(Duration(minutes: i)),
            createdAt: now,
          ),
      ];

      await rebuildNotificationsAfterRestore(
        gateway: gateway,
        reminders: restored,
        now: now,
      );

      expect(gateway.cancelAllCount, 1);
      expect(gateway.scheduled.length, 48);
      expect(gateway.scheduled.containsKey(staleId), isFalse);
    });
  });

  group('Providers, FLN safety & Repository persistence', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wyrm_reminders_test_');
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

    test('clockProvider & notificationGatewayProvider wire cleanly', () {
      final fixed = Clock.fixed(DateTime(2026, 6, 15, 12, 0));
      final fakeGateway = FakeNotificationGateway();

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(fixed),
          notificationGatewayProvider.overrideWithValue(fakeGateway),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await fakeGateway.dispose();
      });

      expect(container.read(clockProvider).now(), DateTime(2026, 6, 15, 12, 0));
      expect(container.read(notificationGatewayProvider), same(fakeGateway));
    });

    test(
      'FlnNotificationGateway handles MissingPluginException safely on desktop',
      () async {
        final gateway = FlnNotificationGateway();
        addTearDown(gateway.dispose);

        await expectLater(gateway.initialize(), completes);
        expect(await gateway.resolveLocalTimezone(), 'UTC');
        expect(
          await gateway.permissionStatus(),
          const NotificationPermissionStatus(),
        );
        expect(await gateway.requestNotificationsPermission(), isFalse);
        expect(await gateway.requestExactAlarmsPermission(), isFalse);
        expect(await gateway.openSystemNotificationSettings(), isFalse);
        expect(await gateway.pendingNotificationIds(), isEmpty);
        expect(await gateway.getLaunchEvent(), isNull);
        await expectLater(
          syncNotifications(
            gateway: gateway,
            reminders: [
              ReminderItem(
                id: 'desktop-safe',
                title: 'Desktop safe',
                scheduledAt: DateTime(2026, 6, 15, 9, 0),
                createdAt: DateTime(2026, 6, 15, 8, 0),
              ),
            ],
            now: DateTime(2026, 6, 15, 8, 0),
          ),
          completes,
        );
        await expectLater(gateway.cancel(1), completes);
        await expectLater(gateway.cancelAll(), completes);
      },
    );

    test('ReminderRepository persists reminders and shade actions update AppDatabase', () async {
      final now = DateTime(2026, 6, 15, 8, 0);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(reminderRepositoryProvider);
      final onceItem = ReminderItem(
        id: 'db-1',
        title: 'Take medicine',
        scheduledAt: DateTime(2026, 6, 15, 8, 30),
        recurrence: ReminderRecurrence.once,
        createdAt: now,
      );
      final dailyItem = ReminderItem(
        id: 'db-2',
        title: 'Stretch',
        scheduledAt: DateTime(2026, 6, 15, 9, 0),
        recurrence: ReminderRecurrence.daily,
        createdAt: now,
      );

      await repo.saveReminders([onceItem, dailyItem]);
      final loaded = await repo.loadReminders();
      expect(loaded, [onceItem, dailyItem]);
      expect(await repo.activeReminders(), [onceItem, dailyItem]);

      final fakeGateway = FakeNotificationGateway();
      addTearDown(fakeGateway.dispose);

      await syncNotifications(
        gateway: fakeGateway,
        reminders: loaded,
        now: now,
      );
      final onceReq = fakeGateway.scheduled.values.firstWhere(
        (e) => e.request.reminderId == 'db-1',
      );

      // Simulate shade Snooze 10m action.
      await handleNotificationShadeAction(
        actionId: FlnNotificationGateway.actionSnoozeId,
        payload: onceReq.request.payloadJson,
        notificationId: onceReq.request.notificationId,
        gateway: fakeGateway,
        clock: Clock.fixed(DateTime(2026, 6, 15, 8, 31)),
      );
      final afterSnooze = await repo.loadReminders();
      final snoozedOnce = afterSnooze.firstWhere((r) => r.id == 'db-1');
      expect(snoozedOnce.isEnabled, isTrue);
      expect(snoozedOnce.snoozedUntil, DateTime(2026, 6, 15, 8, 41));

      // Simulate shade Cancel action.
      await handleNotificationShadeAction(
        actionId: FlnNotificationGateway.actionDismissId,
        payload: onceReq.request.payloadJson,
        notificationId: onceReq.request.notificationId,
        gateway: fakeGateway,
        clock: Clock.fixed(DateTime(2026, 6, 15, 8, 41)),
      );
      final afterDismiss = await repo.loadReminders();
      final dismissedOnce = afterDismiss.firstWhere((r) => r.id == 'db-1');
      expect(dismissedOnce.isEnabled, isFalse);
      expect(dismissedOnce.snoozedUntil, isNull);
      expect(dismissedOnce.lastTriggeredAt, DateTime(2026, 6, 15, 8, 30));

      // Ensure 'reminders' exists in initialized AppDatabase schema & backup validation.
      final dbMap = await AppDatabase.readDatabase();
      expect(dbMap.containsKey('reminders'), isTrue);
      expect(AppDatabase.isBackupJson('{"reminders": []}'), isTrue);
    });
  });
}
