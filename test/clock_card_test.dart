import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/clock/clock.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings.dart';
import 'package:wyrm_desk/widgets/widgets.dart';

/// Test override for AppSettingsNotifier allowing fixed configuration and in-memory updates.
class _TestAppSettingsNotifier extends AppSettingsNotifier {
  final bool is24Hour;
  _TestAppSettingsNotifier({required this.is24Hour});

  @override
  AppSettingsConfig build() => AppSettingsConfig(is24HourFormat: is24Hour);

  @override
  void set24HourFormat(bool value) {
    state = state.copyWith(is24HourFormat: value);
  }
}

void main() {
  testWidgets(
    'ClockContainer renders DigitalClockSmall in small size mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 500,
                child: ClockContainer(
                  currentSize: CardSize.small,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DigitalClockSmall), findsOneWidget);
      expect(find.byType(DigitalClockMedium), findsNothing);
      expect(find.byType(AnalogClock), findsNothing);
      expect(find.text('Clock'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'ClockContainer renders DigitalClockMedium in medium size mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 500,
                child: ClockContainer(
                  currentSize: CardSize.medium,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DigitalClockMedium), findsOneWidget);
      expect(find.byType(DigitalClockSmall), findsNothing);
      expect(find.byType(AnalogClock), findsNothing);
    },
  );

  testWidgets(
    'ClockContainer renders dual AnalogClock and DigitalClockMedium in fullscreen mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 600,
                child: ClockContainer(
                  currentSize: CardSize.fullscreen,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnalogClock), findsOneWidget);
      expect(find.byType(DigitalClockMedium), findsOneWidget);
      expect(find.byType(DigitalClockSmall), findsNothing);
    },
  );

  testWidgets(
    'ClockContainer renders pitch black dual layout in nightstand mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 600,
                child: ClockContainer(
                  currentSize: CardSize.nightstand,
                  onSelectSize: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnalogClock), findsOneWidget);
      expect(find.byType(DigitalClockMedium), findsOneWidget);
      expect(find.byType(DigitalClockSmall), findsNothing);

      final bentoFinder = find.byType(BentoBox);
      expect(bentoFinder, findsOneWidget);
      final bentoBox = tester.widget<BentoBox>(bentoFinder);
      expect(bentoBox.color, Colors.black);
      expect(find.text('Clock'), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byType(CardEditButton), findsOneWidget);
    },
  );

  testWidgets(
    'TopPillBar renders header_text.svg brand wordmark on the left',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TopPillBar(),
            ),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(TopPillBar), findsOneWidget);
    },
  );

  testWidgets(
    'ClockContainer renders custom child when child override is provided',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: ClockContainer(
                  child: Text('Custom Clock'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Clock'), findsOneWidget);
      expect(find.byType(DigitalClockSmall), findsNothing);
    },
  );

  testWidgets(
    'DigitalClock components adapt to 12-hour and 24-hour settings toggles',
    (WidgetTester tester) async {
      final fixedDateTime = DateTime(2026, 9, 17, 14, 45, 30);

      // Render with 12-hour format default (14:45:30 -> 02:45:30 PM).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockTimeProvider.overrideWith((ref) => Stream.value(fixedDateTime)),
            appSettingsProvider.overrideWith(
              () => _TestAppSettingsNotifier(is24Hour: false),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: DigitalClockMedium(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('02'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text(':30'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);

      // Dynamically toggle to 24-hour format and verify reactivity.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DigitalClockMedium)),
      );
      container.read(appSettingsProvider.notifier).set24HourFormat(true);
      await tester.pump();

      expect(find.text('14'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text(':30'), findsOneWidget);
      expect(find.text('PM'), findsNothing);
    },
  );

  testWidgets(
    'AnalogClock renders cleanly with custom size parameter',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnalogClock(size: 250),
              ),
            ),
          ),
        ),
      );

      final clockFinder = find.byType(AnalogClock);
      expect(clockFinder, findsOneWidget);
      expect(tester.getSize(clockFinder), const Size(250, 250));
    },
  );

  test(
    'clockHoursProvider, clockMinutesProvider, and clockSecondsProvider format accurately',
    () async {
      final sampleTime = DateTime(2026, 9, 17, 9, 5, 7);

      final container12h = ProviderContainer(
        overrides: [
          clockTimeProvider.overrideWith((ref) => Stream.value(sampleTime)),
          appSettingsProvider.overrideWith(
            () => _TestAppSettingsNotifier(is24Hour: false),
          ),
        ],
      );
      addTearDown(container12h.dispose);

      // Keep active listener so autoDispose does not immediately terminate.
      final subscription = container12h.listen(clockTimeProvider, (_, _) {});
      await container12h.read(clockTimeProvider.future);

      expect(container12h.read(clockHoursProvider), '09');
      expect(container12h.read(clockMinutesProvider), '05');
      expect(container12h.read(clockSecondsProvider), '07');
      expect(container12h.read(clockPeriodProvider), 'AM');
      expect(container12h.read(timeLeftTodayProvider), '14h 54m left today');

      final angles = container12h.read(analogueAnglesProvider);
      expect(angles.secondAngle, closeTo((7 / 60.0) * 2 * 3.141592653589793, 0.001));

      subscription.close();
    },
  );

  test(
    'timeLeftTodayProvider calculates remaining time until midnight accurately',
    () async {
      final sampleTimeLate = DateTime(2026, 9, 17, 23, 45, 0);

      final container = ProviderContainer(
        overrides: [
          clockTimeProvider.overrideWith((ref) => Stream.value(sampleTimeLate)),
          appSettingsProvider.overrideWith(
            () => _TestAppSettingsNotifier(is24Hour: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep active listener so autoDispose does not immediately terminate.
      final subscription = container.listen(clockTimeProvider, (_, _) {});
      await container.read(clockTimeProvider.future);

      expect(container.read(clockHoursProvider), '23');
      expect(container.read(clockPeriodProvider), isNull);
      expect(container.read(timeLeftTodayProvider), '0h 15m left today');

      subscription.close();
    },
  );

  test(
    'CardLayoutConfig handles nightstand serialization accurately',
    () {
      const config = CardLayoutConfig(
        clock: CardSize.nightstand,
      );

      final json = config.toJson();
      expect(json['clock'], 'nightstand');

      final restored = CardLayoutConfig.fromJson(json);
      expect(restored.clock, CardSize.nightstand);
    },
  );
}
