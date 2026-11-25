import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/features/calendar/calendar_card.dart';
import 'package:wyrm_desk/features/calendar/calendar_model.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/calendar/dusk_date_picker_dialog.dart';

void main() {
  group('CalendarMilestone Model', () {
    test('serializes to JSON and deserializes back faithfully', () {
      final now = DateTime.now();
      final target = now.add(const Duration(days: 10));
      final milestone = CalendarMilestone(
        id: 'ms_1',
        title: 'Project Launch',
        targetDate: target,
        isPinned: true,
        createdAt: now,
      );

      final json = milestone.toJson();
      expect(json['id'], 'ms_1');
      expect(json['title'], 'Project Launch');
      expect(json['is_pinned'], true);

      final deserialized = CalendarMilestone.fromJson(json);
      expect(deserialized.id, 'ms_1');
      expect(deserialized.title, 'Project Launch');
      expect(deserialized.isPinned, true);
      expect(deserialized.targetDate.day, target.day);
    });

    test('calculates relative date labels accurately', () {
      final today = DateTime.now();
      final todayMs = CalendarMilestone(
        id: '1',
        title: 'Today Event',
        targetDate: today,
        createdAt: today,
      );
      expect(todayMs.daysRemaining(), 0);
      expect(todayMs.isToday, true);
      expect(todayMs.isPast, false);
      expect(todayMs.relativeLabel, 'Today');

      final tomorrowMs = CalendarMilestone(
        id: '2',
        title: 'Tomorrow Event',
        targetDate: today.add(const Duration(days: 1)),
        createdAt: today,
      );
      expect(tomorrowMs.daysRemaining(), 1);
      expect(tomorrowMs.relativeLabel, 'Tomorrow');

      final yesterdayMs = CalendarMilestone(
        id: '3',
        title: 'Yesterday Event',
        targetDate: today.subtract(const Duration(days: 1)),
        createdAt: today,
      );
      expect(yesterdayMs.daysRemaining(), -1);
      expect(yesterdayMs.isPast, true);
      expect(yesterdayMs.relativeLabel, 'Yesterday');

      final twoWeeksMs = CalendarMilestone(
        id: '4',
        title: 'Future Event',
        targetDate: today.add(const Duration(days: 14)),
        createdAt: today,
      );
      expect(twoWeeksMs.daysRemaining(), 14);
      expect(twoWeeksMs.relativeLabel, 'In 2 weeks');
    });
  });

  group('CalendarNotifier State', () {
    test('month cycling advances and decrements viewMonth', () {
      final container = ProviderContainer(
        overrides: [
          calendarProvider.overrideWith(
            () => _TestCalendarNotifier(
              CalendarState(
                selectedDate: DateTime(2026, 9, 15),
                viewMonth: DateTime(2026, 9, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarProvider.notifier);

      notifier.nextMonth();
      expect(container.read(calendarProvider).viewMonth, DateTime(2026, 10, 1));

      notifier.prevMonth();
      expect(container.read(calendarProvider).viewMonth, DateTime(2026, 9, 1));

      notifier.setMonth(2027, 1);
      expect(container.read(calendarProvider).viewMonth, DateTime(2027, 1, 1));
    });

    test('selectDate updates selectedDate and syncs viewMonth', () {
      final container = ProviderContainer(
        overrides: [
          calendarProvider.overrideWith(
            () => _TestCalendarNotifier(
              CalendarState(
                selectedDate: DateTime(2026, 9, 15),
                viewMonth: DateTime(2026, 9, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarProvider.notifier);

      notifier.selectDate(DateTime(2026, 11, 20));
      expect(
        container.read(calendarProvider).selectedDate,
        DateTime(2026, 11, 20),
      );
      expect(container.read(calendarProvider).viewMonth, DateTime(2026, 11, 1));
    });

    test('computes year and quarter progress fractions', () {
      final state = CalendarState(
        selectedDate: DateTime(2026, 9, 19),
        viewMonth: DateTime(2026, 9, 1),
      );

      expect(state.yearProgress, greaterThan(0.0));
      expect(state.yearProgress, lessThanOrEqualTo(1.0));
      expect(state.quarterProgress, greaterThan(0.0));
      expect(state.quarterProgress, lessThanOrEqualTo(1.0));
      expect(state.currentQuarter, inInclusiveRange(1, 4));
      expect(state.dayOfYear, inInclusiveRange(1, 366));
    });

    test('manages milestones (add, toggle pin, delete)', () async {
      final container = ProviderContainer(
        overrides: [
          calendarProvider.overrideWith(
            () => _TestCalendarNotifier(
              CalendarState(
                selectedDate: DateTime(2026, 9, 15),
                viewMonth: DateTime(2026, 9, 1),
                milestones: [],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(calendarProvider.notifier);

      await notifier.addMilestone(
        'Launch',
        DateTime(2026, 10, 1),
        isPinned: false,
      );
      expect(container.read(calendarProvider).milestones.length, 1);
      expect(container.read(calendarProvider).milestones.first.title, 'Launch');
      expect(container.read(calendarProvider).milestones.first.isPinned, false);

      final id = container.read(calendarProvider).milestones.first.id;
      await notifier.togglePinMilestone(id);
      expect(container.read(calendarProvider).milestones.first.isPinned, true);
      expect(container.read(calendarProvider).heroMilestone?.title, 'Launch');

      await notifier.deleteMilestone(id);
      expect(container.read(calendarProvider).milestones.isEmpty, true);
    });
  });

  group('CalendarCard Widget', () {
    testWidgets(
      'renders Small layout with header, month navigation, and Sunday start',
      (WidgetTester tester) async {
        final initialDate = DateTime(2026, 9, 19);
        final notifier = _TestCalendarNotifier(
          CalendarState(
            selectedDate: initialDate,
            viewMonth: DateTime(2026, 9, 1),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              calendarProvider.overrideWith(() => notifier),
              appSettingsProvider.overrideWith(
                () => _TestSettingsNotifier(
                  const AppSettingsConfig(startWeekOnMonday: false),
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 340,
                  height: 440,
                  child: CalendarCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text('September 2026'), findsOneWidget);

        // Verify Sunday start has 'S' as first weekday label
        expect(find.text('S'), findsWidgets);

        // Tap next month chevron
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pump();

        expect(find.text('October 2026'), findsOneWidget);
      },
    );

    testWidgets('renders Monday start when configured in settings', (
      WidgetTester tester,
    ) async {
      final initialDate = DateTime(2026, 9, 19);
      final notifier = _TestCalendarNotifier(
        CalendarState(
          selectedDate: initialDate,
          viewMonth: DateTime(2026, 9, 1),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarProvider.overrideWith(() => notifier),
            appSettingsProvider.overrideWith(
              () => _TestSettingsNotifier(
                const AppSettingsConfig(startWeekOnMonday: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 440,
                child: CalendarCard(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('M'), findsWidgets);
    });

    testWidgets(
      'renders Medium dual-pane layout with temporal inspector and progress bars',
      (WidgetTester tester) async {
        final initialDate = CalendarState.todayMidnight;
        final milestone = CalendarMilestone(
          id: 'ms_test',
          title: 'Demo Milestone',
          targetDate: initialDate.add(const Duration(days: 6)),
          isPinned: true,
          createdAt: DateTime.now(),
        );

        final notifier = _TestCalendarNotifier(
          CalendarState(
            selectedDate: initialDate,
            viewMonth: DateTime(initialDate.year, initialDate.month, 1),
            milestones: [milestone],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [calendarProvider.overrideWith(() => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 700,
                  height: 450,
                  child: CalendarCard(currentSize: CardSize.medium),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Calendar'), findsOneWidget);
        final monthName = monthNames[initialDate.month - 1];
        expect(find.text('$monthName ${initialDate.year}'), findsOneWidget);
        // Today button is hidden near chevrons when marker is already on the current date
        expect(find.widgetWithText(InkWell, 'Today'), findsNothing);
        expect(find.text('Travel'), findsOneWidget);
        expect(find.textContaining('${initialDate.year}'), findsWidgets);
        expect(find.textContaining('${initialDate.day}'), findsWidgets);
        expect(find.text('Milestones & Countdowns'), findsOneWidget);
        expect(find.text('Demo Milestone'), findsOneWidget);

        // Verify circular delete button in milestone item
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Tap delete milestone button
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();

        expect(notifier.state.milestones.isEmpty, true);
      },
    );

    testWidgets(
      'Today button appears when navigated away and disappears after reset',
      (WidgetTester tester) async {
        final initialDate = CalendarState.todayMidnight;
        final awayYear = initialDate.year + 1;
        final notifier = _TestCalendarNotifier(
          CalendarState(
            selectedDate: initialDate,
            viewMonth: DateTime(awayYear, 1, 1),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [calendarProvider.overrideWith(() => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 340,
                  height: 440,
                  child: CalendarCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );

        expect(find.text('January $awayYear'), findsOneWidget);
        // Today button is visible because we are viewing January of next year
        expect(find.widgetWithText(InkWell, 'Today'), findsOneWidget);

        // Tap the navigation Today button
        await tester.tap(find.widgetWithText(InkWell, 'Today').first);
        await tester.pump();

        final today = CalendarState.todayMidnight;
        final expectedMonthName = monthNames[today.month - 1];
        expect(find.text('$expectedMonthName ${today.year}'), findsOneWidget);

        // After resetting to today, the Today button should no longer be visible
        expect(find.widgetWithText(InkWell, 'Today'), findsNothing);
      },
    );

    testWidgets('Travel button opens date picker dialog with TRAVEL button', (
      WidgetTester tester,
    ) async {
      final initialDate = DateTime(2026, 9, 19);
      final notifier = _TestCalendarNotifier(
        CalendarState(
          selectedDate: initialDate,
          viewMonth: DateTime(2026, 9, 1),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarProvider.overrideWith(() => notifier)],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 440,
                child: CalendarCard(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Travel'), findsOneWidget);

      // Tap the Travel button to launch date picker
      await tester.tap(find.widgetWithText(InkWell, 'Travel'));
      await tester.pumpAndSettle();

      // Verify date picker opened and shows TRAVEL confirm button
      expect(find.text('TRAVEL'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Small card with constrained height resizes and wraps all dates without overflow',
      (WidgetTester tester) async {
        final initialDate = DateTime(2026, 10, 15);
        final notifier = _TestCalendarNotifier(
          CalendarState(
            selectedDate: initialDate,
            viewMonth: DateTime(2026, 10, 1),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [calendarProvider.overrideWith(() => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 250,
                  child: CalendarCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );

        expect(find.text('October 2026'), findsOneWidget);
        // All dates from day 1 to day 31 are rendered and visible
        expect(find.text('1'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(find.text('31'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('DuskDatePickerDialog Year Scrolling', () {
    testWidgets(
      'toggles to year mode and displays dynamically windowed years',
      (WidgetTester tester) async {
        final initialDate = DateTime(2026, 9, 19);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DuskDatePickerDialog(
                initialDate: initialDate,
                firstDate: DateTime(1),
                lastDate: DateTime(9999, 12, 31),
                confirmText: 'Travel',
                cancelText: 'Cancel',
              ),
            ),
          ),
        );

        // Initially in day mode
        expect(find.byKey(const ValueKey('day_picker')), findsOneWidget);
        expect(find.text('2026'), findsOneWidget);

        // Tap year chip to switch to year mode
        await tester.tap(find.text('2026'));
        await tester.pumpAndSettle();

        // Now in year picker mode
        expect(find.byKey(const ValueKey('year_picker')), findsOneWidget);
        // Selected year tile is visible
        expect(find.text('2026'), findsWidgets);
        // Surrounding windowed years are generated
        expect(find.text('2025'), findsOneWidget);
        expect(find.text('2027'), findsOneWidget);

        // Tap on another year tile to travel there
        await tester.tap(find.text('2027'));
        await tester.pumpAndSettle();

        // Should return to day mode with 2027 selected
        expect(find.byKey(const ValueKey('day_picker')), findsOneWidget);
        expect(find.text('2027'), findsOneWidget);
      },
    );

    testWidgets('clamps lower bound to Year 1 and never creates Year 0', (
      WidgetTester tester,
    ) async {
      final initialDate = DateTime(2, 1, 15);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuskDatePickerDialog(
              initialDate: initialDate,
              firstDate: DateTime(1),
              lastDate: DateTime(9999, 12, 31),
              confirmText: 'Travel',
              cancelText: 'Cancel',
            ),
          ),
        ),
      );

      // Tap year chip
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('year_picker')), findsOneWidget);
      // Year 1 is present as the lower bound
      expect(find.text('1'), findsOneWidget);
      // Year 0 or negative years must not exist
      expect(find.text('0'), findsNothing);
      expect(find.text('-1'), findsNothing);
    });
  });
}

class _TestCalendarNotifier extends CalendarNotifier {
  final CalendarState initial;
  _TestCalendarNotifier(this.initial);

  @override
  CalendarState build() => initial;

  @override
  Future<void> addMilestone(
    String title,
    DateTime targetDate, {
    bool isPinned = false,
  }) async {
    final ms = CalendarMilestone(
      id: (state.milestones.length + 1).toString(),
      title: title,
      targetDate: targetDate,
      isPinned: isPinned,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(milestones: [...state.milestones, ms]);
  }

  @override
  Future<void> deleteMilestone(String id) async {
    state = state.copyWith(
      milestones: state.milestones.where((m) => m.id != id).toList(),
    );
  }

  @override
  Future<void> togglePinMilestone(String id) async {
    state = state.copyWith(
      milestones: state.milestones.map((m) {
        if (m.id == id) return m.copyWith(isPinned: !m.isPinned);
        return m;
      }).toList(),
    );
  }
}

class _TestSettingsNotifier extends AppSettingsNotifier {
  final AppSettingsConfig initial;
  _TestSettingsNotifier(this.initial);

  @override
  AppSettingsConfig build() => initial;
}
