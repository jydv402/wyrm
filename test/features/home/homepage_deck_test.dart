import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_card.dart';
import 'package:wyrm_desk/features/clock/clock_card.dart';
import 'package:wyrm_desk/widgets/top_pill_bar.dart';
import 'package:wyrm_desk/widgets/card_edit_button.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/home/homepage.dart';
import 'package:wyrm_desk/features/reminder/reminder_card.dart';
import 'package:wyrm_desk/features/sharing/sharing_card.dart';
import 'package:wyrm_desk/features/tasks/tasks_card.dart';

/// Integration tests for the homepage deck shell: card rendering, in-place
/// card-size popup menus, and scroll/stack behaviour across size changes.
void main() {
  testWidgets(
    'HomePage renders pinned top bar, horizontal deck, all cards, and scroll indicator',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      // Verify pinned top bar and horizontal deck.
      expect(find.byType(TopPillBar), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify all six domain cards are rendered.
      expect(find.byType(ClockContainer), findsOneWidget);
      expect(find.byType(HabitsCard), findsOneWidget);
      expect(find.byType(CalendarCard), findsOneWidget);
      expect(find.byType(TasksCard), findsOneWidget);
      expect(find.byType(ReminderCard), findsOneWidget);
      expect(find.byType(SharingCard), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(2));

      // Verify presence of corner cycle buttons on all six cards.
      expect(find.byType(CardEditButton<CardSize>), findsNWidgets(6));
    },
  );

  testWidgets(
    'Clock card in-place popup menu allows selecting Small, Medium, and Fullscreen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      final clockFinder = find.byType(ClockContainer);
      final initialWidth = tester.getSize(clockFinder).width;

      final clockMenuButton = find.descendant(
        of: clockFinder,
        matching: find.byType(CardEditButton<CardSize>),
      );

      // Tap corner button to expand in-place popup menu.
      await tester.tap(clockMenuButton);
      await tester.pumpAndSettle();

      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Fullscreen'), findsOneWidget);
      expect(find.text('Nightstand'), findsOneWidget);

      // Select Medium.
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      final mediumWidth = tester.getSize(clockFinder).width;
      expect(mediumWidth, greaterThan(initialWidth));

      // Tap menu button again and select Nightstand.
      await tester.tap(clockMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nightstand'));
      await tester.pumpAndSettle();

      final nightstandWidth = tester.getSize(clockFinder).width;
      expect(nightstandWidth, greaterThanOrEqualTo(1200));

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
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      final habitsFinder = find.byType(HabitsCard);
      final habitsMenuButton = find.descendant(
        of: habitsFinder,
        matching: find.byType(CardEditButton<CardSize>),
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

  testWidgets(
    'Reminder and Sharing cards stack as squares when Small and unstack independently on resize',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );
      await tester.pumpAndSettle();

      final reminderFinder = find.byType(ReminderCard);
      final sharingFinder = find.byType(SharingCard);
      expect(reminderFinder, findsOneWidget);
      expect(sharingFinder, findsOneWidget);

      // Primary 3 columns fit within 1280px, so Reminder & Sharing sit to the right
      // as stacked 1:1 square cards.
      final reminderRect = tester.getRect(reminderFinder);
      final sharingRect = tester.getRect(sharingFinder);
      expect(reminderRect.left, greaterThanOrEqualTo(1280.0));
      expect(reminderRect.width, closeTo(reminderRect.height, 1.0));
      expect(sharingRect.width, closeTo(sharingRect.height, 1.0));
      expect(reminderRect.left, closeTo(sharingRect.left, 0.5));
      expect(sharingRect.top, greaterThan(reminderRect.bottom));

      // Scroll to Reminder and resize it independently to Medium.
      final reminderMenuButton = find.descendant(
        of: reminderFinder,
        matching: find.byType(CardEditButton<CardSize>),
      );
      await tester.ensureVisible(reminderMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(reminderMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();

      final unstackedReminder = tester.getRect(reminderFinder);
      final unstackedSharing = tester.getRect(sharingFinder);
      expect(unstackedReminder.width, greaterThan(reminderRect.width));
      // Sharing unstacks into its own full-height column while keeping Small width.
      expect(unstackedSharing.left, greaterThan(unstackedReminder.right));
      expect(unstackedSharing.height, greaterThan(sharingRect.height));
      expect(unstackedSharing.width, closeTo(sharingRect.width, 1.0));

      // Resize Sharing independently to Fullscreen.
      final sharingMenuButton = find.descendant(
        of: sharingFinder,
        matching: find.byType(CardEditButton<CardSize>),
      );
      await tester.ensureVisible(sharingMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(sharingMenuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fullscreen'));
      await tester.pumpAndSettle();

      expect(tester.getSize(sharingFinder).width, greaterThanOrEqualTo(1200));

      // Restore both to Small and confirm they re-stack as squares.
      await tester.ensureVisible(reminderMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(reminderMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(sharingMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(sharingMenuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Small'));
      await tester.pumpAndSettle();

      final reStackedReminder = tester.getRect(reminderFinder);
      final reStackedSharing = tester.getRect(sharingFinder);
      expect(reStackedReminder.left, closeTo(reStackedSharing.left, 0.5));
      expect(reStackedReminder.width, closeTo(reStackedReminder.height, 1.0));
      expect(reStackedSharing.width, closeTo(reStackedSharing.height, 1.0));
    },
  );

  testWidgets(
    'Reminder and Sharing cards render without overflow at 2.0x text scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReminderCard), findsOneWidget);
      expect(find.byType(SharingCard), findsOneWidget);
    },
  );
}
