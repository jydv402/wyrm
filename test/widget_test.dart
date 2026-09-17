import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/calendar/calendar.dart';
import 'package:wyrm_desk/clock/clock.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/home/home.dart';
import 'package:wyrm_desk/tasks/tasks.dart';

void main() {
  testWidgets(
    'HomePage renders pinned top bar, horizontal deck, all cards, and scroll indicator',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      // Verify pinned top bar and horizontal deck.
      expect(find.byType(TopPillBar), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify all four domain cards are rendered.
      expect(find.byType(ClockContainer), findsOneWidget);
      expect(find.byType(HabitsCard), findsOneWidget);
      expect(find.byType(CalendarCard), findsOneWidget);
      expect(find.byType(TasksCard), findsOneWidget);

      // Verify presence of corner cycle buttons on all four cards.
      expect(find.byType(CardEditButton), findsNWidgets(4));
    },
  );

  testWidgets(
    'Clock card in-place popup menu allows selecting Small, Medium, and Fullscreen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      final clockFinder = find.byType(ClockContainer);
      final initialWidth = tester.getSize(clockFinder).width;

      final clockMenuButton = find.descendant(
        of: clockFinder,
        matching: find.byType(CardEditButton),
      );

      // Tap corner button to expand in-place popup menu.
      await tester.tap(clockMenuButton);
      await tester.pumpAndSettle();

      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Fullscreen'), findsOneWidget);

      // Select Medium.
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      final mediumWidth = tester.getSize(clockFinder).width;
      expect(mediumWidth, greaterThan(initialWidth));

      // Tap menu button again and select Fullscreen.
      await tester.tap(clockMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fullscreen'));
      await tester.pumpAndSettle();

      final fullscreenWidth = tester.getSize(clockFinder).width;
      expect(fullscreenWidth, greaterThanOrEqualTo(1200));

      // Page must still be horizontally scrollable in Fullscreen.
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Tap menu button again and restore to Small.
      await tester.tap(clockMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();

      final restoredWidth = tester.getSize(clockFinder).width;
      expect(restoredWidth, lessThan(mediumWidth));
    },
  );

  testWidgets(
    'Habits card in-place popup menu allows selecting Medium and Fullscreen with adaptive unstacking',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      final habitsFinder = find.byType(HabitsCard);
      final habitsMenuButton = find.descendant(
        of: habitsFinder,
        matching: find.byType(CardEditButton),
      );

      // Expand popup menu on Habits card and select Medium.
      await tester.tap(habitsMenuButton);
      await tester.pumpAndSettle();

      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Fullscreen'), findsOneWidget);

      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      // Verify both Habits and Calendar remain in the horizontal tree as separate columns.
      expect(find.byType(HabitsCard), findsOneWidget);
      expect(find.byType(CalendarCard), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Expand popup menu on Habits card and select Fullscreen.
      await tester.tap(habitsMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fullscreen'));
      await tester.pumpAndSettle();

      final habitsFullscreenWidth = tester.getSize(habitsFinder).width;
      expect(habitsFullscreenWidth, greaterThanOrEqualTo(1200));

      // Scrollable deck remains active to access other widgets.
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Restore to Small.
      await tester.ensureVisible(habitsMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(habitsMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitsCard), findsOneWidget);
      expect(find.byType(CalendarCard), findsOneWidget);
    },
  );

  test(
    'CardLayoutConfig serializes to and deserializes from JSON accurately',
    () {
      const config = CardLayoutConfig(
        clock: CardSize.medium,
        habits: CardSize.fullscreen,
        calendar: CardSize.small,
        tasks: CardSize.medium,
      );

      final jsonMap = config.toJson();
      expect(jsonMap['clock'], 'medium');
      expect(jsonMap['habits'], 'fullscreen');
      expect(jsonMap['calendar'], 'small');
      expect(jsonMap['tasks'], 'medium');

      final restored = CardLayoutConfig.fromJson(jsonMap);
      expect(restored.clock, CardSize.medium);
      expect(restored.habits, CardSize.fullscreen);
      expect(restored.calendar, CardSize.small);
      expect(restored.tasks, CardSize.medium);
    },
  );
}
