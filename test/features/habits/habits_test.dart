import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/features/habits/habit_form_content.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';

void main() {
  group('HabitItem Model', () {
    test('serializes to JSON and deserializes back faithfully', () {
      final habit = HabitItem(
        id: 'habit-1',
        title: 'Drink Water',
        type: HabitType.numeric,
        targetValue: 8,
        unit: 'cups',
        iconName: 'water_drop',
        completions: {'2026-09-18': 8, '2026-09-19': 6, '2026-09-20': 8},
        createdAt: DateTime(2026, 9, 1),
      );

      final json = habit.toJson();
      expect(json['id'], 'habit-1');
      expect(json['title'], 'Drink Water');
      expect(json['type'], 'numeric');
      expect(json['target_value'], 8);
      expect(json['targetValue'], 8);
      expect(json['unit'], 'cups');
      expect(json['icon_name'], 'water_drop');
      expect(json['iconName'], 'water_drop');
      expect(json['completions']['2026-09-20'], 8);

      final deserialized = HabitItem.fromJson(json);
      expect(deserialized.id, habit.id);
      expect(deserialized.title, habit.title);
      expect(deserialized.type, HabitType.numeric);
      expect(deserialized.targetValue, 8);
      expect(deserialized.unit, 'cups');
      expect(deserialized.iconName, 'water_drop');
      expect(deserialized.completions['2026-09-20'], 8);
    });

    test(
      'calculates completion status accurately for binary and numeric types',
      () {
        final binaryHabit = HabitItem(
          id: 'h1',
          title: 'Meditate',
          type: HabitType.binary,
          targetValue: 1,
          completions: {'2026-09-20': 1, '2026-09-19': 0},
          createdAt: DateTime(2026, 9, 1),
        );

        expect(binaryHabit.isCompletedOn(DateTime(2026, 9, 20)), isTrue);
        expect(binaryHabit.isCompletedOn(DateTime(2026, 9, 19)), isFalse);
        expect(binaryHabit.isCompletedOn(DateTime(2026, 9, 18)), isFalse);

        final numericHabit = HabitItem(
          id: 'h2',
          title: 'Walk Steps',
          type: HabitType.numeric,
          targetValue: 10,
          completions: {'2026-09-20': 10, '2026-09-19': 7},
          createdAt: DateTime(2026, 9, 1),
        );

        expect(numericHabit.isCompletedOn(DateTime(2026, 9, 20)), isTrue);
        expect(numericHabit.isCompletedOn(DateTime(2026, 9, 19)), isFalse);
      },
    );

    test('calculates current streak with same-day grace', () {
      final today = DateTime(2026, 9, 20);

      final habitNoHistory = HabitItem(
        id: 'h0',
        title: 'Empty',
        createdAt: DateTime(2026, 9, 1),
      );
      expect(habitNoHistory.currentStreak(today), 0);

      final habitTodayDone = HabitItem(
        id: 'h1',
        title: 'Today Done',
        completions: {'2026-09-20': 1, '2026-09-19': 1, '2026-09-18': 1},
        createdAt: DateTime(2026, 9, 1),
      );
      expect(habitTodayDone.currentStreak(today), 3);

      final habitGrace = HabitItem(
        id: 'h2',
        title: 'Grace',
        completions: {'2026-09-19': 1, '2026-09-18': 1},
        createdAt: DateTime(2026, 9, 1),
      );
      expect(habitGrace.currentStreak(today), 2);

      final habitBroken = HabitItem(
        id: 'h3',
        title: 'Broken',
        completions: {'2026-09-18': 1},
        createdAt: DateTime(2026, 9, 1),
      );
      expect(habitBroken.currentStreak(today), 0);
    });

    test('calculates completed days count for the designated month', () {
      final month = DateTime(2026, 9, 1);
      final habit = HabitItem(
        id: 'hm',
        title: 'Monthly Count Test',
        type: HabitType.numeric,
        targetValue: 4,
        completions: {
          '2026-09-01': 4,
          '2026-09-02': 2,
          '2026-09-03': 4,
          '2026-08-31': 4,
        },
        createdAt: DateTime(2026, 8, 1),
      );

      expect(habit.monthCompletedDaysCount(month), 2);
    });

    test(
      'generates calendar weeks matrix (5 or 6 weeks of 7 days) correctly',
      () {
        final month = DateTime(2026, 9, 1);
        final habit = HabitItem(
          id: 'hc',
          title: 'Calendar Weeks Test',
          type: HabitType.numeric,
          targetValue: 4,
          completions: {'2026-09-01': 4, '2026-09-02': 2},
          createdAt: DateTime(2026, 8, 1),
        );

        final weeks = habit.getMonthlyCalendarWeeks(
          month,
          startWeekOnMonday: true,
        );
        expect(weeks.length, isIn([5, 6]));
        for (final week in weeks) {
          expect(week.length, 7);
        }

        final sept1 = weeks
            .expand((w) => w)
            .firstWhere(
              (c) =>
                  c.date?.year == 2026 &&
                  c.date?.month == 9 &&
                  c.date?.day == 1,
            );
        expect(sept1.isCurrentMonth, isTrue);
        expect(sept1.intensity, 1.0);

        final sept2 = weeks
            .expand((w) => w)
            .firstWhere(
              (c) =>
                  c.date?.year == 2026 &&
                  c.date?.month == 9 &&
                  c.date?.day == 2,
            );
        expect(sept2.intensity, 0.5);
      },
    );

    test('resets streaks at month boundary', () {
      final sept1 = DateTime(2026, 9, 1);
      final habit = HabitItem(
        id: 'hs',
        title: 'Streak Reset Test',
        completions: {'2026-08-30': 1, '2026-08-31': 1},
        createdAt: DateTime(2026, 8, 1),
      );

      expect(habit.currentStreak(sept1), 0);

      final habitDoneSept1 = habit.copyWith(
        completions: {...habit.completions, '2026-09-01': 1},
      );
      expect(habitDoneSept1.currentStreak(sept1), 1);
    });
  });

  group('HabitsNotifier State Management', () {
    test('adds, edits, and deletes habits cleanly', () async {
      final container = ProviderContainer(
        overrides: [
          habitsProvider.overrideWith(
            () => _TestHabitsNotifier(const HabitsState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(habitsProvider.notifier);
      expect(container.read(habitsProvider).habits, isEmpty);

      final h1 = HabitItem(
        id: 'h1',
        title: 'Coding',
        type: HabitType.binary,
        createdAt: DateTime.now(),
      );
      await notifier.addHabit(h1);
      expect(container.read(habitsProvider).habits.length, 1);
      expect(container.read(habitsProvider).activeHabit?.title, 'Coding');

      final h1Edited = h1.copyWith(title: 'Deep Coding');
      await notifier.editHabit(h1Edited);
      expect(container.read(habitsProvider).activeHabit?.title, 'Deep Coding');

      await notifier.deleteHabit('h1');
      expect(container.read(habitsProvider).habits, isEmpty);
      expect(container.read(habitsProvider).activeHabit, isNull);
    });

    test('toggles binary habit completion and steps numeric habit', () async {
      final container = ProviderContainer(
        overrides: [
          habitsProvider.overrideWith(
            () => _TestHabitsNotifier(const HabitsState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(habitsProvider.notifier);
      final today = DateTime(2026, 9, 20);

      final binaryHabit = HabitItem(
        id: 'hb',
        title: 'Meditate',
        type: HabitType.binary,
        targetValue: 1,
        createdAt: DateTime.now(),
      );
      final numericHabit = HabitItem(
        id: 'hn',
        title: 'Drink Water',
        type: HabitType.numeric,
        targetValue: 8,
        createdAt: DateTime.now(),
      );

      await notifier.addHabit(binaryHabit);
      await notifier.addHabit(numericHabit);

      await notifier.toggleCompletion('hb', today);
      expect(
        container.read(habitsProvider).habits[0].isCompletedOn(today),
        isTrue,
      );

      await notifier.toggleCompletion('hb', today);
      expect(
        container.read(habitsProvider).habits[0].isCompletedOn(today),
        isFalse,
      );

      await notifier.stepCompletion('hn', 3, today);
      expect(
        container.read(habitsProvider).habits[1].completionCountOn(today),
        3,
      );
      expect(
        container.read(habitsProvider).habits[1].isCompletedOn(today),
        isFalse,
      );

      await notifier.stepCompletion('hn', 5, today);
      expect(
        container.read(habitsProvider).habits[1].completionCountOn(today),
        8,
      );
      expect(
        container.read(habitsProvider).habits[1].isCompletedOn(today),
        isTrue,
      );

      await notifier.stepCompletion('hn', -2, today);
      expect(
        container.read(habitsProvider).habits[1].completionCountOn(today),
        6,
      );
      expect(
        container.read(habitsProvider).habits[1].isCompletedOn(today),
        isFalse,
      );
    });

    test('cycles carousel forward and backward with wrapping', () async {
      final container = ProviderContainer(
        overrides: [
          habitsProvider.overrideWith(
            () => _TestHabitsNotifier(const HabitsState()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(habitsProvider.notifier);

      for (var i = 1; i <= 3; i++) {
        await notifier.addHabit(
          HabitItem(id: 'h$i', title: 'Habit $i', createdAt: DateTime.now()),
        );
      }

      notifier.setCarouselIndex(0);
      expect(container.read(habitsProvider).selectedCarouselIndex, 0);

      notifier.cycleCarousel(1);
      expect(container.read(habitsProvider).selectedCarouselIndex, 1);

      notifier.cycleCarousel(1);
      expect(container.read(habitsProvider).selectedCarouselIndex, 2);

      notifier.cycleCarousel(1);
      expect(container.read(habitsProvider).selectedCarouselIndex, 0);

      notifier.cycleCarousel(-1);
      expect(container.read(habitsProvider).selectedCarouselIndex, 2);
    });
  });

  group('HabitsCard Widget', () {
    testWidgets('renders empty state when no habits exist', (
      WidgetTester tester,
    ) async {
      final notifier = _TestHabitsNotifier(const HabitsState(habits: []));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [habitsProvider.overrideWith(() => notifier)],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: HabitsCard(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('No habits for today'), findsOneWidget);
      expect(find.text('Add a habit'), findsOneWidget);
    });

    testWidgets(
      'renders Small carousel layout with active habit details and week strip',
      (WidgetTester tester) async {
        final today = DateTime.now();
        final testHabits = [
          HabitItem(
            id: 'h1',
            title: 'Morning Yoga',
            type: HabitType.binary,
            targetValue: 1,
            iconName: 'fitness_center',
            completions: {HabitItem.dateKey(today): 1},
            createdAt: DateTime(2026, 9, 1),
          ),
          HabitItem(
            id: 'h2',
            title: 'Hydration',
            type: HabitType.numeric,
            targetValue: 8,
            unit: 'cups',
            iconName: 'water_drop',
            completions: {HabitItem.dateKey(today): 5},
            createdAt: DateTime(2026, 9, 1),
          ),
        ];

        final notifier = _TestHabitsNotifier(
          HabitsState(habits: testHabits, selectedCarouselIndex: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [habitsProvider.overrideWith(() => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 340,
                  height: 250,
                  child: HabitsCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Habits'), findsOneWidget);
        expect(find.text('Morning Yoga'), findsOneWidget);
        expect(find.text('1/2'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsAtLeastNWidgets(1));

        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Hydration'), findsOneWidget);
        expect(find.text('2/2'), findsOneWidget);
        expect(find.text('5/8 cups'), findsOneWidget);
      },
    );

    testWidgets('renders Medium multi-column card grid without overflow', (
      WidgetTester tester,
    ) async {
      final testHabits = [
        HabitItem(
          id: 'h1',
          title: 'Read Book',
          type: HabitType.binary,
          createdAt: DateTime(2026, 9, 1),
        ),
        HabitItem(
          id: 'h2',
          title: 'Walk Steps',
          type: HabitType.numeric,
          targetValue: 10,
          unit: 'km',
          createdAt: DateTime(2026, 9, 1),
        ),
      ];

      final notifier = _TestHabitsNotifier(
        HabitsState(habits: testHabits, selectedCarouselIndex: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [habitsProvider.overrideWith(() => notifier)],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 450,
                child: HabitsCard(currentSize: CardSize.medium),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Read Book'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.text('Read Book'), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Walk Steps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders Fullscreen vertically scrollable 2-row grid without overflow',
      (WidgetTester tester) async {
        final testHabits = [
          HabitItem(
            id: 'h1',
            title: 'Read Book',
            type: HabitType.binary,
            createdAt: DateTime(2026, 9, 1),
          ),
          HabitItem(
            id: 'h2',
            title: 'Walk Steps',
            type: HabitType.numeric,
            targetValue: 10,
            unit: 'km',
            createdAt: DateTime(2026, 9, 1),
          ),
        ];

        final notifier = _TestHabitsNotifier(
          HabitsState(habits: testHabits, selectedCarouselIndex: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [habitsProvider.overrideWith(() => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 1000,
                  height: 600,
                  child: HabitsCard(currentSize: CardSize.fullscreen),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Read Book'), findsOneWidget);
        expect(find.text('Walk Steps'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders Small layout in constrained ultra-compact height without overflow',
      (WidgetTester tester) async {
        final today = DateTime.now();
        final testHabits = [
          HabitItem(
            id: 'h1',
            title: 'Stretch',
            type: HabitType.binary,
            targetValue: 1,
            iconName: 'fitness_center',
            completions: {HabitItem.dateKey(today): 1},
            createdAt: DateTime(2026, 9, 1),
          ),
        ];

        final notifier = _TestHabitsNotifier(
          HabitsState(habits: testHabits, selectedCarouselIndex: 0),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [habitsProvider.overrideWith(() => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 125,
                  child: HabitsCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Stretch'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders GitHub heatmap with month name in Medium size', (
      WidgetTester tester,
    ) async {
      final testHabits = [
        HabitItem(
          id: 'h1',
          title: 'Morning Run',
          type: HabitType.binary,
          createdAt: DateTime(2026, 9, 1),
        ),
      ];

      final notifier = _TestHabitsNotifier(
        HabitsState(habits: testHabits, selectedCarouselIndex: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [habitsProvider.overrideWith(() => notifier)],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 380,
                child: HabitsCard(currentSize: CardSize.medium),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Morning Run'), findsOneWidget);
      final monthName = monthNames[DateTime.now().month - 1];
      expect(find.textContaining(monthName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'buildHabitGlyph renders Icon for known tokens/emojis and Text for custom emojis',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  buildHabitGlyph('water_drop', size: 24),
                  buildHabitGlyph('💧', size: 24),
                  buildHabitGlyph('🍎', size: 24),
                ],
              ),
            ),
          ),
        );

        // water_drop and 💧 resolve to Icons.water_drop_rounded
        expect(find.byIcon(Icons.water_drop_rounded), findsNWidgets(2));
        // 🍎 is a custom emoji, rendered directly as a Text widget
        expect(find.text('🍎'), findsOneWidget);
      },
    );
  });
}

class _TestHabitsNotifier extends HabitsNotifier {
  final HabitsState initial;
  _TestHabitsNotifier(this.initial);

  @override
  HabitsState build() => initial;
}
