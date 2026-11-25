import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/repositories/reminder_repository.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/home/homepage.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_card.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/reminder/widgets/alarm_ring_overlay.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_tile.dart';
import 'package:wyrm_desk/features/settings/settings_page.dart';
import 'package:wyrm_desk/native/alarm_audio_gateway.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/fake_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

class _InMemoryReminderRepository implements ReminderRepository {
  List<ReminderItem> _items = const <ReminderItem>[];

  @override
  Future<List<ReminderItem>> loadReminders() async => _items;

  @override
  Future<List<ReminderItem>> activeReminders() async =>
      _items.where((item) => item.isEnabled).toList();

  @override
  Future<void> saveReminders(List<ReminderItem> reminders) async {
    _items = List<ReminderItem>.unmodifiable(reminders);
  }
}

class _FakeSettingsNotifier extends AppSettingsNotifier {
  final AppSettingsConfig _initial;
  _FakeSettingsNotifier(this._initial);

  @override
  AppSettingsConfig build() => _initial;
}

class _FakeCardLayoutNotifier extends CardLayoutNotifier {
  final CardLayoutConfig _initial;
  _FakeCardLayoutNotifier(this._initial);

  @override
  CardLayoutConfig build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer createTestContainer({
    required DateTime fixedNow,
    required FakeNotificationGateway gateway,
    required FakeAlarmAudioGateway audio,
    Stream<DateTime>? clockStream,
    AppSettingsConfig settings = const AppSettingsConfig(),
    CardLayoutConfig layout = const CardLayoutConfig(),
  }) {
    final clock = Clock.fixed(fixedNow);
    final repo = _InMemoryReminderRepository();
    return ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        clockTimeProvider.overrideWith(
          (ref) => clockStream ?? Stream.value(fixedNow),
        ),
        reminderRepositoryProvider.overrideWithValue(repo),
        notificationGatewayProvider.overrideWithValue(gateway),
        alarmAudioGatewayProvider.overrideWithValue(audio),
        appSettingsProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
        cardLayoutProvider.overrideWith(() => _FakeCardLayoutNotifier(layout)),
        localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
      ],
    );
  }

  group('AlarmRingOverlayHost & AlarmRingOverlay', () {
    testWidgets(
      'renders landscape left Cancel/Snooze + right Title split layout and handles Dismiss/Snooze',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 8, 30, 5);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;
        final created = await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'Morning Standup',
              scheduledAt: DateTime(2026, 6, 15, 8, 30),
              recurrence: ReminderRecurrence.weekdays,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AlarmRingOverlayHost(
                child: Scaffold(body: Center(child: Text('Underlying Screen'))),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlarmRingOverlay), findsNothing);
        expect(find.text('Underlying Screen'), findsOneWidget);

        // Trigger ringing alarm.
        await container
            .read(activeAlarmProvider.notifier)
            .triggerAlarm(created, DateTime(2026, 6, 15, 8, 30));
        await tester.pumpAndSettle();

        expect(find.byType(AlarmRingOverlay), findsOneWidget);
        expect(find.text('ALARM RINGING'), findsOneWidget);
        expect(find.text('Morning Standup'), findsOneWidget);
        expect(find.text('Weekdays'), findsOneWidget);
        expect(find.text('8:30'), findsOneWidget);
        expect(find.text(':05'), findsOneWidget);
        expect(find.text('AM'), findsOneWidget);
        expect(find.text('8:30 AM'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Snooze 10m'), findsOneWidget);

        // Verify left Cancel/Snooze zone sits to the left of right title zone
        // and button heights respect minimum touch target sizes.
        final cancelBtn = find.byKey(const ValueKey('alarm_cancel_button'));
        final snoozeBtn = find.byKey(const ValueKey('alarm_snooze_button'));
        final titleFinder = find.text('Morning Standup');

        final cancelRect = tester.getRect(cancelBtn);
        final snoozeRect = tester.getRect(snoozeBtn);
        final titleRect = tester.getRect(titleFinder);

        expect(cancelRect.height, greaterThanOrEqualTo(96.0));
        expect(snoozeRect.height, greaterThanOrEqualTo(76.0));
        expect(cancelRect.right, lessThan(titleRect.left));
        expect(snoozeRect.right, lessThan(titleRect.left));

        // Verify title typography size is bold 42-56px in AppColors.textPrimary.
        final titleWidget = tester.widget<Text>(titleFinder);
        expect(titleWidget.style?.fontSize, inInclusiveRange(42.0, 56.0));
        expect(titleWidget.style?.color, AppColors.textPrimary);

        // Verify PopScope(canPop: false) guards back presses.
        final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
        expect(popScope.canPop, isFalse);

        // Tap Snooze 10m -> clears overlay, stops chime, sets snoozedUntil.
        await tester.tap(snoozeBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlarmRingOverlay), findsNothing);
        expect(container.read(activeAlarmProvider), isNull);
        expect(audio.isPlaying, isFalse);
        final afterSnooze = container.read(remindersProvider).items.single;
        expect(afterSnooze.snoozedUntil, now.add(const Duration(minutes: 10)));

        // Re-trigger with snooze active and tap Cancel -> disables/dismisses cleanly.
        await container
            .read(activeAlarmProvider.notifier)
            .triggerAlarm(afterSnooze, afterSnooze.snoozedUntil!);
        await tester.pumpAndSettle();

        expect(find.text('Snoozed'), findsOneWidget);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlarmRingOverlay), findsNothing);
        expect(container.read(activeAlarmProvider), isNull);
        final afterDismiss = container.read(remindersProvider).items.single;
        expect(afterDismiss.snoozedUntil, isNull);
        expect(afterDismiss.isEnabled, isTrue);
      },
    );

    testWidgets(
      'overlays Nightstand mode and adapts to 24h format and narrow stacked layout',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(520, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 20, 45, 9);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
          settings: const AppSettingsConfig(is24HourFormat: true),
          layout: const CardLayoutConfig(clock: CardSize.nightstand),
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child ?? const SizedBox.shrink(),
              ),
              home: const AlarmRingOverlayHost(
                child: HomePage(clockWidget: SizedBox()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reminder = ReminderItem(
          id: 'night-rem',
          title: 'Take Evening Vitamin',
          scheduledAt: DateTime(2026, 6, 15, 20, 45),
          recurrence: ReminderRecurrence.custom,
          customWeekdays: const [DateTime.monday, DateTime.friday],
          createdAt: now,
        );

        await container
            .read(activeAlarmProvider.notifier)
            .triggerAlarm(reminder, DateTime(2026, 6, 15, 20, 45));
        await tester.pumpAndSettle();

        expect(find.byType(AlarmRingOverlay), findsOneWidget);
        expect(find.text('Take Evening Vitamin'), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);
        expect(find.text('Mon, Fri'), findsOneWidget);
        expect(find.text('20:45'), findsNWidgets(2));
        expect(find.text('PM'), findsNothing);

        // Stacked column fallback on narrow viewport (< 720px).
        final titleRect = tester.getRect(find.text('Take Evening Vitamin'));
        final cancelRect = tester.getRect(
          find.byKey(const ValueKey('alarm_cancel_button')),
        );
        expect(cancelRect.top, greaterThan(titleRect.bottom));

        // Cleanly unmount HomePage timers/platform channels.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      },
    );
  });

  group('ReminderCard Small, Medium, and Fullscreen tiers', () {
    testWidgets(
      'shows empty state CTA and optional permission banner only when disabled',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 360);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 9, 0);
        final gateway = FakeNotificationGateway(
          currentPermissionStatus: const NotificationPermissionStatus(
            notificationsEnabled: false,
            exactAlarmsAllowed: false,
          ),
        );
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 340,
                  height: 340,
                  child: ReminderCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DuskCardEmptyState), findsOneWidget);
        expect(find.text('Add reminder'), findsOneWidget);
        expect(
          find.text('Notifications disabled — tap to allow'),
          findsOneWidget,
        );

        // Grant permission via banner tap -> banner disappears.
        await tester.tap(find.text('Notifications disabled — tap to allow'));
        await tester.pumpAndSettle();
        expect(
          find.text('Notifications disabled — tap to allow'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Small tier renders next-up countdown strip, compact tiles, and toggle switch',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(400, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 9, 0);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;
        final rem1 = await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'Drink Water',
              scheduledAt: DateTime(2026, 6, 15, 9, 15),
            );
        await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'Breakfast Tomorrow',
              scheduledAt: DateTime(2026, 6, 16, 8, 0),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 340,
                  height: 340,
                  child: ReminderCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ReminderNextUpBanner), findsOneWidget);
        expect(find.byType(ReminderTile), findsNWidgets(2));
        expect(find.text('2'), findsOneWidget);
        expect(find.text('In 15m'), findsWidgets);
        expect(find.text('Tomorrow'), findsWidgets);
        expect(find.text('Drink Water'), findsWidgets);

        // Toggle first reminder off.
        await tester.tap(find.byKey(ValueKey('reminder_toggle_${rem1.id}')));
        await tester.pumpAndSettle();
        expect(container.read(remindersProvider).enabledItems.length, 1);
      },
    );

    testWidgets(
      'Medium tier renders hero banner + ListView.builder tiles with delete action',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 9, 0);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;
        final rem = await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'Stretch Break',
              scheduledAt: DateTime(2026, 6, 15, 9, 30),
              recurrence: ReminderRecurrence.daily,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 700,
                  height: 700,
                  child: ReminderCard(currentSize: CardSize.medium),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('NEXT UP'), findsOneWidget);
        expect(find.text('In 30m'), findsWidgets);
        expect(find.byType(ListView), findsOneWidget);
        expect(
          find.byKey(ValueKey('reminder_delete_${rem.id}')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(ValueKey('reminder_delete_${rem.id}')));
        await tester.pumpAndSettle();
        expect(container.read(remindersProvider).items, isEmpty);
      },
    );

    testWidgets(
      'Fullscreen tier filters All / Active / Recurring and opens editor via + New Reminder',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 9, 0);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;
        await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'One-Time Call',
              scheduledAt: DateTime(2026, 6, 15, 10, 0),
              recurrence: ReminderRecurrence.once,
              isEnabled: false,
            );
        await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'Daily Walk',
              scheduledAt: DateTime(2026, 6, 15, 11, 0),
              recurrence: ReminderRecurrence.daily,
              isEnabled: true,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const Scaffold(
                      body: ReminderCard(currentSize: CardSize.fullscreen),
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.reminderEditor,
                    builder: (_, state) => ReminderEditorScreen(
                      reminderToEdit: state.extra as ReminderItem?,
                      reminderId: state.uri.queryParameters['id'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ReminderTile), findsNWidgets(2));
        expect(find.text('+ New Reminder'), findsOneWidget);
        expect(find.text('Notifications allowed'), findsOneWidget);

        // Filter to Active -> hides disabled One-Time Call.
        await tester.tap(find.byKey(const ValueKey('reminder_filter_active')));
        await tester.pumpAndSettle();
        expect(find.byType(ReminderTile), findsNWidgets(1));
        expect(find.text('Daily Walk'), findsWidgets);

        // Filter to Recurring -> shows Daily Walk only.
        await tester.tap(
          find.byKey(const ValueKey('reminder_filter_recurring')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReminderTile), findsNWidgets(1));

        // Tap + New Reminder -> navigates to ReminderEditorScreen.
        await tester.tap(find.byKey(const ValueKey('reminder_new_button')));
        await tester.pumpAndSettle();
        expect(find.byType(ReminderEditorScreen), findsOneWidget);
        expect(find.text('New Reminder'), findsOneWidget);
      },
    );
  });

  group('ReminderEditorScreen & ReminderFormContent', () {
    testWidgets(
      'creates reminder with +30m quick offset, auto-wraps past Once time to Tomorrow, and supports Custom weekdays',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 14, 0);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;

        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const Scaffold(
                body: ReminderCard(currentSize: CardSize.medium),
              ),
            ),
            GoRoute(
              path: AppRoutes.reminderEditor,
              builder: (_, state) => ReminderEditorScreen(
                reminderToEdit: state.extra as ReminderItem?,
                reminderId: state.uri.queryParameters['id'],
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open editor via + button.
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();

        expect(find.text('New Reminder'), findsOneWidget);
        expect(find.text('Triggers in 15m'), findsOneWidget);

        // Tap +30m offset chip -> 2:30 PM, Triggers in 30m.
        await tester.tap(find.byKey(const ValueKey('reminder_offset_30')));
        await tester.pumpAndSettle();
        expect(find.text('2:30 PM'), findsOneWidget);
        expect(find.text('Triggers in 30m'), findsOneWidget);

        // Switch AM/PM to AM -> 2:30 AM is in the past today, auto-wraps to Tomorrow.
        await tester.tap(find.byKey(const ValueKey('reminder_period_am')));
        await tester.pumpAndSettle();
        expect(
          find.text('Time passed today — auto-scheduled for Tomorrow'),
          findsOneWidget,
        );
        expect(find.text('Triggers in 12h 30m'), findsOneWidget);

        // Switch to Custom recurrence and toggle Monday + Wednesday.
        await tester.tap(
          find.byKey(const ValueKey('reminder_recurrence_custom')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('reminder_weekday_3')));
        await tester.pumpAndSettle();

        // Type title via attached virtual-keyboard controller and save.
        final titleField = tester.widget<TextField>(find.byType(TextField));
        titleField.controller?.text = 'Gym Session';
        await tester.pumpAndSettle();
        expect(find.text('Gym Session'), findsWidgets);
        await tester.tap(find.text('Save Reminder'));
        await tester.pumpAndSettle();

        final items = container.read(remindersProvider).items;
        expect(items.length, 1);
        expect(items.single.title, 'Gym Session');
        expect(items.single.recurrence, ReminderRecurrence.custom);
        expect(items.single.scheduledAt.hour, 2);
        expect(items.single.scheduledAt.minute, 30);
      },
    );

    testWidgets(
      'supports Edit mode via query parameter id, Hour/Min steppers, and Delete',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 10, 0);
        final gateway = FakeNotificationGateway();
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
          settings: const AppSettingsConfig(is24HourFormat: true),
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;
        final seeded = await container
            .read(remindersProvider.notifier)
            .addReminder(
              title: 'Tea Time',
              scheduledAt: DateTime(2026, 6, 15, 16, 0),
              recurrence: ReminderRecurrence.daily,
            );

        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const Scaffold(
                body: ReminderCard(currentSize: CardSize.medium),
              ),
            ),
            GoRoute(
              path: AppRoutes.reminderEditor,
              builder: (_, state) => ReminderEditorScreen(
                reminderToEdit: state.extra as ReminderItem?,
                reminderId: state.uri.queryParameters['id'],
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Deep-link edit via ?id=...
        router.push('${AppRoutes.reminderEditor}?id=${seeded.id}');
        await tester.pumpAndSettle();

        expect(find.text('Edit Reminder'), findsOneWidget);
        expect(find.text('Tea Time'), findsWidgets);
        // 24h mode hides AM/PM buttons.
        expect(find.byKey(const ValueKey('reminder_period_am')), findsNothing);

        // Increment hour and minute via steppers -> 17:01.
        await tester.tap(find.byKey(const ValueKey('reminder_hour_inc')));
        await tester.tap(find.byKey(const ValueKey('reminder_min_inc')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        final updated = container.read(remindersProvider).items.single;
        expect(updated.scheduledAt.hour, 17);
        expect(updated.scheduledAt.minute, 1);

        // Open edit by tapping tile and delete reminder.
        await tester.tap(find.byKey(ValueKey('reminder_tile_${updated.id}')));
        await tester.pumpAndSettle();

        final deleteBtn = find.byKey(
          const ValueKey('reminder_editor_delete_button'),
        );
        await tester.ensureVisible(deleteBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(container.read(remindersProvider).items, isEmpty);
      },
    );
  });

  group('Settings RemindersSection preview & permissions', () {
    testWidgets(
      'triggers permission requests and launches Preview Alarm Screen over Settings',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime(2026, 6, 15, 11, 0);
        final gateway = FakeNotificationGateway(
          currentPermissionStatus: const NotificationPermissionStatus(
            notificationsEnabled: false,
            exactAlarmsAllowed: false,
          ),
        );
        final audio = FakeAlarmAudioGateway();
        final container = createTestContainer(
          fixedNow: now,
          gateway: gateway,
          audio: audio,
        );
        addTearDown(() async {
          container.dispose();
          await gateway.dispose();
        });

        await container.read(remindersProvider.notifier).initialized;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AlarmRingOverlayHost(child: SettingsPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reminders & Alarms'), findsOneWidget);
        expect(find.text('Allow Notifications'), findsOneWidget);
        expect(find.text('Precise Background Timing'), findsOneWidget);
        expect(find.text('Preview Alarm Screen'), findsOneWidget);

        // Request notifications & exact alarms.
        await tester.ensureVisible(find.text('Allow'));
        await tester.tap(find.text('Allow'));
        await tester.pumpAndSettle();
        expect(
          container.read(remindersProvider).permissions.notificationsEnabled,
          isTrue,
        );

        await tester.ensureVisible(find.text('Enable'));
        await tester.tap(find.text('Enable'));
        await tester.pumpAndSettle();
        expect(
          container.read(remindersProvider).permissions.exactAlarmsAllowed,
          isTrue,
        );

        // Trigger Preview Alarm Screen.
        final previewBtn = find.byKey(
          const ValueKey('settings_preview_alarm_button'),
        );
        await tester.ensureVisible(previewBtn);
        await tester.tap(previewBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlarmRingOverlay), findsOneWidget);
        expect(find.text('Preview Alarm'), findsOneWidget);
        expect(find.text('Preview'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('alarm_cancel_button')));
        await tester.pumpAndSettle();
        expect(find.byType(AlarmRingOverlay), findsNothing);
        expect(container.read(remindersProvider).items, isEmpty);
      },
    );
  });
}
