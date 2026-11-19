import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/features/clock/clock_backdrop.dart';
import 'package:wyrm_desk/features/clock/clock_backdrop_motion.dart';
import 'package:wyrm_desk/features/clock/clock_card.dart';
import 'package:wyrm_desk/features/clock/clock_date_line.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/clock/clock_sun_countdown.dart';
import 'package:wyrm_desk/features/clock/clock_face_analog.dart';
import 'package:wyrm_desk/features/clock/clock_face_digital_medium.dart';
import 'package:wyrm_desk/features/clock/clock_face_digital_small.dart';
import 'package:wyrm_desk/features/home/top_pill_bar.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/widgets/bento_box.dart';
import 'package:wyrm_desk/widgets/card_edit_button.dart';

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
  testWidgets('ClockContainer renders DigitalClockSmall in small size mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 500,
              child: ClockContainer(currentSize: CardSize.small),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DigitalClockSmall), findsOneWidget);
    expect(find.byType(ClockDateLine), findsOneWidget);
    expect(find.byType(DigitalClockMedium), findsNothing);
    expect(find.byType(AnalogClock), findsNothing);
    expect(find.byType(ClockSunCountdown), findsOneWidget);
    expect(find.text('Clock'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets('clock countdown is pinned to the bottom-left of the card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 640,
              child: ClockContainer(currentSize: CardSize.small),
            ),
          ),
        ),
      ),
    );

    final card = tester.getRect(find.byType(ClockContainer));
    final countdown = tester.getRect(find.byType(ClockSunCountdown));
    final dateLine = tester.getRect(find.byType(ClockDateLine));

    // The card's left rail: date up top, countdown on the bottom corner.
    expect(countdown.left - card.left, lessThan(40));
    expect(card.bottom - countdown.bottom, lessThan(40));
    expect(countdown.top, greaterThan(dateLine.bottom));
  });

  testWidgets('ClockContainer renders DigitalClockMedium in medium size mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 500,
              child: ClockContainer(currentSize: CardSize.medium),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DigitalClockMedium), findsOneWidget);
    expect(find.byType(ClockDateLine), findsOneWidget);
    expect(find.byType(DigitalClockSmall), findsNothing);
    expect(find.byType(AnalogClock), findsNothing);
    expect(find.byType(ClockSunCountdown), findsOneWidget);
  });

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
                child: ClockContainer(currentSize: CardSize.fullscreen),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnalogClock), findsOneWidget);
      expect(find.byType(DigitalClockMedium), findsOneWidget);
      expect(find.byType(ClockDateLine), findsOneWidget);
      expect(find.byType(DigitalClockSmall), findsNothing);
      expect(find.byType(ClockSunCountdown), findsOneWidget);
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
      expect(find.byType(ClockDateLine), findsOneWidget);
      expect(find.byType(DigitalClockSmall), findsNothing);
      expect(find.byType(ClockSunCountdown), findsOneWidget);

      final bentoFinder = find.byType(BentoBox);
      expect(bentoFinder, findsOneWidget);
      final bentoBox = tester.widget<BentoBox>(bentoFinder);
      expect(bentoBox.color, Colors.black);
      expect(find.text('Clock'), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byType(CardEditButton<CardSize>), findsOneWidget);
    },
  );

  testWidgets('TopPillBar renders header_text.svg brand wordmark on the left', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: TopPillBar())),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(TopPillBar), findsOneWidget);
  });

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
                child: ClockContainer(child: Text('Custom Clock')),
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
            clockTimeProvider.overrideWith(
              (ref) => Stream.value(fixedDateTime),
            ),
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
      expect(find.text(': 30'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);

      // Dynamically toggle to 24-hour format and verify reactivity.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DigitalClockMedium)),
      );
      container.read(appSettingsProvider.notifier).set24HourFormat(true);
      await tester.pump();

      expect(find.text('14'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text(': 30'), findsOneWidget);
      expect(find.text('PM'), findsNothing);
    },
  );

  testWidgets(
    'DigitalClockSmall displays stacked time, seconds, AM/PM tag and adapts to 24-hour setting',
    (WidgetTester tester) async {
      final fixedDateTime = DateTime(2026, 9, 17, 9, 5, 24);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockTimeProvider.overrideWith(
              (ref) => Stream.value(fixedDateTime),
            ),
            appSettingsProvider.overrideWith(
              () => _TestAppSettingsNotifier(is24Hour: false),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 500,
                child: DigitalClockSmall(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('09'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expect(find.text(' : 24'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DigitalClockSmall)),
      );
      container.read(appSettingsProvider.notifier).set24HourFormat(true);
      await tester.pump();

      expect(find.text('09'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expect(find.text(' : 24'), findsOneWidget);
      expect(find.text('AM'), findsNothing);
    },
  );

  testWidgets('AnalogClock renders cleanly with custom size parameter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: AnalogClock(size: 250))),
        ),
      ),
    );

    final clockFinder = find.byType(AnalogClock);
    expect(clockFinder, findsOneWidget);
    expect(tester.getSize(clockFinder), const Size(250, 250));
  });

  testWidgets('AnalogClock sizes dynamically when size is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 400, height: 400, child: AnalogClock()),
            ),
          ),
        ),
      ),
    );

    final clockFinder = find.byType(AnalogClock);
    expect(clockFinder, findsOneWidget);
    final containerFinder = find.descendant(
      of: clockFinder,
      matching: find.byType(Container),
    );
    // 400 * 0.75 = 300
    expect(tester.getSize(containerFinder), const Size(300, 300));
  });

  test('clockHoursProvider, clockMinutesProvider, and clockSecondsProvider format accurately', () async {
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
    expect(container12h.read(timeLeftTodayPartsProvider), (
      hours: 14,
      minutes: 54,
    ));

    final angles = container12h.read(clockHandAnglesProvider);
    expect(angles.second, closeTo((7 / 60.0) * 2 * 3.141592653589793, 0.001));

    subscription.close();
  });

  test('timeLeftTodayPartsProvider calculates remaining time until midnight accurately', () async {
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
    expect(container.read(timeLeftTodayPartsProvider), (hours: 0, minutes: 15));

    subscription.close();
  });

  test('clockBackgroundAssetProvider maps hour ranges accurately', () async {
    final hoursToExpected = {
      4: 'assets/card_bg/clock/clock_1.png',
      6: 'assets/card_bg/clock/clock_1.png',
      7: 'assets/card_bg/clock/clock_2.png',
      10: 'assets/card_bg/clock/clock_2.png',
      11: 'assets/card_bg/clock/clock_3.png',
      15: 'assets/card_bg/clock/clock_3.png',
      16: 'assets/card_bg/clock/clock_4.png',
      18: 'assets/card_bg/clock/clock_4.png',
      19: 'assets/card_bg/clock/clock_5.png',
      23: 'assets/card_bg/clock/clock_5.png',
      0: 'assets/card_bg/clock/clock_5.png',
      3: 'assets/card_bg/clock/clock_5.png',
    };

    for (final entry in hoursToExpected.entries) {
      final testTime = DateTime(2026, 9, 17, entry.key, 30);
      final container = ProviderContainer(
        overrides: [
          clockTimeProvider.overrideWith((ref) => Stream.value(testTime)),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(clockTimeProvider, (_, _) {});
      await container.read(clockTimeProvider.future);

      expect(
        container.read(clockBackgroundAssetProvider),
        entry.value,
        reason: 'Failed for hour ${entry.key}',
      );
      subscription.close();
    }
  });

  testWidgets(
    'ClockContainer renders image background in standard mode and omits it in nightstand mode',
    (WidgetTester tester) async {
      final morningTime = DateTime(2026, 9, 17, 8, 30);

      // Standard small mode renders Image.asset with clock_2.png
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockTimeProvider.overrideWith((ref) => Stream.value(morningTime)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: ClockContainer(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final imageFinder = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          final asset = widget.image as AssetImage;
          return asset.assetName == 'assets/card_bg/clock/clock_2.png';
        }
        if (widget is Image && widget.image is ResizeImage) {
          final inner = (widget.image as ResizeImage).imageProvider;
          if (inner is AssetImage) {
            return inner.assetName == 'assets/card_bg/clock/clock_2.png';
          }
        }
        return false;
      });
      expect(imageFinder, findsOneWidget);

      // Nightstand mode omits image backdrop
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockTimeProvider.overrideWith((ref) => Stream.value(morningTime)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: ClockContainer(currentSize: CardSize.nightstand),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
    },
  );

  test('clockBackdropMotion paces the drift in pixels per second', () {
    const motion = ClockBackdropMotion();
    expect(motion.step, 0.5);
    expect(motion.interval, const Duration(seconds: 1));
    expect(motion.speed, 0.5);
    // The pace is the step over the interval, so either can be retuned alone.
    expect(
      const ClockBackdropMotion(
        step: 4,
        interval: Duration(milliseconds: 100),
      ).speed,
      40,
    );
  });

  testWidgets(
    'ClockBackdrop steps the photograph on each tick without easing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 600,
              child: ClockBackdrop(
                assetPath: 'assets/card_bg/clock/clock_2.png',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final start = tester.getTopLeft(find.byType(Image)).dx;
      expect(start, 0, reason: 'the panorama starts at its left edge');

      // One second of 0.5 px step at 1s interval is 1 step, 0.5 px.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(find.byType(Image)).dx, closeTo(-0.5, 0.01));
    },
  );

  testWidgets('ClockBackdrop turns around at each edge of the panorama', (
    WidgetTester tester,
  ) async {
    // A 300 x 600 card shows a 1414 px wide panorama, so the travel is ~1114.
    const travel = 600 * 3168 / 1344 - 300;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 600,
            child: ClockBackdrop(assetPath: 'assets/card_bg/clock/clock_2.png'),
          ),
        ),
      ),
    );
    await tester.pump();

    // Walk past the far edge and back, checking the photograph never leaves the
    // card and never shows a gap at either end.
    for (var second = 1; second <= 70; second++) {
      await tester.pump(const Duration(seconds: 1));
      final dx = tester.getTopLeft(find.byType(Image)).dx;
      expect(dx, lessThanOrEqualTo(0), reason: 'after ${second}s');
      expect(
        dx,
        greaterThanOrEqualTo(-travel - 0.5),
        reason: 'after ${second}s',
      );
    }
  });

  testWidgets('ClockBackdrop holds a centred crop under reduced motion', (
    WidgetTester tester,
  ) async {
    const travel = 600 * 3168 / 1344 - 300;

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 300,
              height: 600,
              child: ClockBackdrop(
                assetPath: 'assets/card_bg/clock/clock_2.png',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final held = tester.getTopLeft(find.byType(Image)).dx;
    expect(held, closeTo(-travel / 2, 0.5));

    await tester.pump(const Duration(seconds: 5));
    expect(tester.getTopLeft(find.byType(Image)).dx, held);
  });

  testWidgets('ClockBackdrop stops drifting while scrolled out of view', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 600,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: const Row(
                children: [
                  SizedBox(
                    width: 300,
                    height: 600,
                    child: ClockBackdrop(
                      assetPath: 'assets/card_bg/clock/clock_2.png',
                    ),
                  ),
                  SizedBox(width: 900, height: 600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(find.byType(Image)).dx, lessThan(0));

    controller.jumpTo(700); // Walk the card out of the viewport.
    await tester.pump();

    final parked = tester.getTopLeft(find.byType(Image)).dx;
    await tester.pump(const Duration(seconds: 5));
    expect(
      tester.getTopLeft(find.byType(Image)).dx,
      parked,
      reason: 'invisible cards do not animate',
    );
  });
}
