import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/calendar/milestone_form_content.dart';
import 'package:wyrm_desk/habits/habit_form_content.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard.dart';
import 'package:wyrm_desk/server/network_info.dart';
import 'package:wyrm_desk/settings/settings_page.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_form_content.dart';
import 'package:wyrm_desk/tasks/tasks.dart';

class _FakeAppSettingsNotifier extends AppSettingsNotifier {
  final AppSettingsConfig _initial;
  _FakeAppSettingsNotifier(this._initial);

  @override
  AppSettingsConfig build() => _initial;
}

class _TestTasksNotifier extends TasksNotifier {
  final List<TaskItem> _initial;
  _TestTasksNotifier(this._initial);

  @override
  List<TaskItem> build() => _initial;
}

class _TestHabitsNotifier extends HabitsNotifier {
  final List<HabitItem> _initial;
  _TestHabitsNotifier(this._initial);

  @override
  HabitsState build() => HabitsState(habits: _initial);
}

void main() {
  group('Settings useClassicModalSheet Configuration', () {
    test('serializes and deserializes use_classic_modal_sheet correctly', () {
      const config = AppSettingsConfig(useClassicModalSheet: true);
      final json = config.toJson();
      expect(json['use_classic_modal_sheet'], true);

      final deserialized = AppSettingsConfig.fromJson(json);
      expect(deserialized.useClassicModalSheet, true);

      final toggled = deserialized.copyWith(useClassicModalSheet: false);
      expect(toggled.useClassicModalSheet, false);
    });

    testWidgets('SettingsPage renders Classic Modal Sheet toggle switch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
            appSettingsProvider.overrideWith(
              () => _FakeAppSettingsNotifier(
                const AppSettingsConfig(useClassicModalSheet: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classic Modal Sheet'), findsOneWidget);
      expect(
        find.text('Use bottom sheet instead of 2-pane keyboard editor'),
        findsOneWidget,
      );

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
    });
  });

  group('TwoPaneKeyboardScaffold Component', () {
    testWidgets('renders 40/60 split with form on left and preview on right',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var saved = false;
      final textController = TextEditingController(text: 'Initial');

      await tester.pumpWidget(
        MaterialApp(
          home: TwoPaneKeyboardScaffold(
            title: 'Test Editor',
            onSave: () => saved = true,
            formBuilder: (context, keyboard) {
              return Column(
                children: [
                  const Text('Left Form Content'),
                  InAppKeyboardTextField(controller: textController),
                ],
              );
            },
            previewBuilder: (context) {
              return Text('Preview: ${textController.text}');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Editor'), findsOneWidget);
      expect(find.text('Left Form Content'), findsOneWidget);
      expect(find.text('LIVE PREVIEW'), findsOneWidget);
      expect(find.text('Preview: Initial'), findsOneWidget);
      expect(find.byType(InAppKeyboardWidget), findsOneWidget);

      final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save');
      expect(saveButtonFinder, findsOneWidget);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();
      expect(saved, true);

      textController.dispose();
    });
  });

  group('Adaptive Form Widgets & WYSIWYG Previews', () {
    testWidgets('HabitFormContent and HabitPreviewTile render and interact',
        (WidgetTester tester) async {
      final titleController = TextEditingController(text: 'Morning Jog');
      final unitController = TextEditingController(text: 'km');
      var habitType = HabitType.binary;
      var count = 1;
      var icon = 'bolt';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      HabitFormContent(
                        titleController: titleController,
                        unitController: unitController,
                        habitType: habitType,
                        targetCount: count,
                        selectedIcon: icon,
                        onTypeChanged: (t) => setState(() => habitType = t),
                        onTargetCountChanged: (c) => setState(() => count = c),
                        onIconChanged: (i) => setState(() => icon = i),
                      ),
                      HabitPreviewTile(
                        title: titleController.text,
                        type: habitType,
                        targetCount: count,
                        unit: unitController.text,
                        iconName: icon,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning Jog'), findsWidgets);
      expect(find.text('Check-in (Done/Not Done)'), findsOneWidget);
      expect(find.text('Target Count (e.g. 8 cups)'), findsOneWidget);

      final numericTypeChip = find.text('Target Count (e.g. 8 cups)');
      await tester.tap(numericTypeChip);
      await tester.pumpAndSettle();
      expect(habitType, HabitType.numeric);

      titleController.dispose();
      unitController.dispose();
    });

    testWidgets('MilestoneFormContent and MilestonePreviewCard render and interact',
        (WidgetTester tester) async {
      final titleController = TextEditingController(text: 'Launch Day');
      var date = DateTime(2026, 10, 15);
      var isPinned = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    MilestoneFormContent(
                      titleController: titleController,
                      selectedDate: date,
                      isPinned: isPinned,
                      onDateChanged: (d) => setState(() => date = d),
                      onPinnedChanged: (p) => setState(() => isPinned = p),
                    ),
                    MilestonePreviewCard(
                      title: titleController.text,
                      targetDate: date,
                      isPinned: isPinned,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Milestone Name'), findsOneWidget);
      expect(find.text('Launch Day'), findsWidgets);
      expect(find.text('Target Date'), findsOneWidget);
      expect(find.text('Pin to Countdown Pill'), findsOneWidget);

      final pinSwitch = find.byType(Switch);
      expect(pinSwitch, findsOneWidget);
      await tester.tap(pinSwitch);
      await tester.pumpAndSettle();
      expect(isPinned, true);

      titleController.dispose();
    });

    testWidgets('TaskFormContent and TaskPreviewCard render and interact',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final titleController = TextEditingController(text: 'Review PR');
      var priority = 'normal';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      TaskFormContent(
                        titleController: titleController,
                        selectedPriority: priority,
                        onPriorityChanged: (p) => setState(() => priority = p),
                      ),
                      TaskPreviewCard(
                        title: titleController.text,
                        priority: priority,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task Description'), findsOneWidget);
      expect(find.text('Review PR'), findsWidgets);
      expect(find.text('Normal Priority'), findsOneWidget);
      expect(find.text('High Priority'), findsOneWidget);

      final highPriorityChip = find.text('High Priority');
      await tester.tap(highPriorityChip);
      await tester.pumpAndSettle();
      expect(priority, 'high');

      titleController.dispose();
    });
  });

  group('2-Pane Editor Navigation Trigger Tests', () {
    testWidgets('TasksCard opens TwoPaneKeyboardScaffold by default',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(
              () => _FakeAppSettingsNotifier(
                const AppSettingsConfig(useClassicModalSheet: false),
              ),
            ),
            tasksProvider.overrideWith(() => _TestTasksNotifier([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: TasksCard(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find.byIcon(Icons.add_rounded);
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.byType(TwoPaneKeyboardScaffold), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);
      expect(find.byType(InAppKeyboardWidget), findsOneWidget);
    });

    testWidgets('HabitsCard opens TwoPaneKeyboardScaffold by default',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(
              () => _FakeAppSettingsNotifier(
                const AppSettingsConfig(useClassicModalSheet: false),
              ),
            ),
            habitsProvider.overrideWith(() => _TestHabitsNotifier([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: HabitsCard(currentSize: CardSize.medium),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find.byIcon(Icons.add_rounded);
      expect(addButton, findsWidgets);
      await tester.tap(addButton.first);
      await tester.pumpAndSettle();

      expect(find.byType(TwoPaneKeyboardScaffold), findsOneWidget);
      expect(find.text('New Habit'), findsOneWidget);
      expect(find.byType(InAppKeyboardWidget), findsOneWidget);
    });
  });
}
