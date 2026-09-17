import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/widgets/widgets.dart';

void main() {
  testWidgets('DeskLayout renders horizontally scrollable deck with cards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DeskLayout(),
          ),
        ),
      ),
    );

    // Verify pinned top bar and horizontal deck.
    expect(find.byType(TopPillBar), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Verify presence of all primary domain cards.
    expect(find.byType(ClockContainer), findsOneWidget);
    expect(find.byType(HabitsCard), findsOneWidget);
    expect(find.byType(CalendarCard), findsOneWidget);
    expect(find.byType(TasksCard), findsOneWidget);

    // Verify edit buttons on each card.
    expect(find.byType(CardEditButton), findsNWidgets(4));
  });

  testWidgets(
      'Clock card edit button opens dialog with Small, Medium, and Full Screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DeskLayout(),
          ),
        ),
      ),
    );

    // Tap the edit button on the clock container.
    final clockEditFinder = find.descendant(
      of: find.byType(ClockContainer),
      matching: find.byType(CardEditButton),
    );
    await tester.tap(clockEditFinder);
    await tester.pumpAndSettle();

    // Verify the size dialog is displayed with clock-specific options.
    expect(find.byType(CardSizeDialog), findsOneWidget);
    expect(find.text('Clock Card Size'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Full Screen'), findsOneWidget);

    // Select Medium and verify dismissal and animated transition.
    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();
    expect(find.byType(CardSizeDialog), findsNothing);
  });

  testWidgets(
      'Standard bento card edit button opens dialog and toggles full screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DeskLayout(),
          ),
        ),
      ),
    );

    // Tap edit on Habits card.
    final habitsEditFinder = find.descendant(
      of: find.byType(HabitsCard),
      matching: find.byType(CardEditButton),
    );
    await tester.tap(habitsEditFinder);
    await tester.pumpAndSettle();

    // Verify dialog shows two sizing options for standard cards.
    expect(find.byType(CardSizeDialog), findsOneWidget);
    expect(find.text('Habits Card Size'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Full Screen'), findsOneWidget);

    // Expand to full screen.
    await tester.tap(find.text('Full Screen'));
    await tester.pumpAndSettle();

    // Verify full screen presentation.
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(HabitsCard), findsOneWidget);

    // Tap restore icon on full screen habits card to exit.
    final restoreButtonFinder = find.descendant(
      of: find.byType(HabitsCard),
      matching: find.byType(CardEditButton),
    );
    await tester.tap(restoreButtonFinder);
    await tester.pumpAndSettle();

    // Verify deck is restored.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
      'Clock card smoothly transitions between Small, Medium, and Full Screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DeskLayout(),
          ),
        ),
      ),
    );

    // Verify initial clock width.
    final initialClockFinder = find.byType(ClockContainer);
    final initialSize = tester.getSize(initialClockFinder);

    // Expand clock to Medium.
    final clockEditFinder = find.descendant(
      of: find.byType(ClockContainer),
      matching: find.byType(CardEditButton),
    );
    await tester.tap(clockEditFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();

    // Verify clock expanded horizontally.
    final mediumSize = tester.getSize(initialClockFinder);
    expect(mediumSize.width, greaterThan(initialSize.width));

    // Expand clock to Full Screen.
    await tester.tap(clockEditFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full Screen'));
    await tester.pumpAndSettle();

    // Verify full screen covers the horizontal deck.
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ClockContainer), findsOneWidget);

    // Restore to default layout.
    final restoreButtonFinder = find.descendant(
      of: find.byType(ClockContainer),
      matching: find.byType(CardEditButton),
    );
    await tester.tap(restoreButtonFinder);
    await tester.pumpAndSettle();

    // Verify return to default deck.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
      'HomePage renders consolidated dashboard layout directly without extra wrappers',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(TopPillBar), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(ClockContainer), findsOneWidget);
    expect(find.byType(HabitsCard), findsOneWidget);
    expect(find.byType(CalendarCard), findsOneWidget);
    expect(find.byType(TasksCard), findsOneWidget);
  });
}

