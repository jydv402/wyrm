import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/tasks.dart';

void main() {
  group('TaskItem Model', () {
    test('serializes to JSON and deserializes back faithfully', () {
      final now = DateTime.now();
      final task = TaskItem(
        id: 'task_1',
        title: 'Complete Phase 1 tasks',
        isCompleted: true,
        priority: 'high',
        createdAt: now,
      );

      final json = task.toJson();
      expect(json['id'], 'task_1');
      expect(json['title'], 'Complete Phase 1 tasks');
      expect(json['is_completed'], true);
      expect(json['priority'], 'high');

      final deserialized = TaskItem.fromJson(json);
      expect(deserialized.id, 'task_1');
      expect(deserialized.title, 'Complete Phase 1 tasks');
      expect(deserialized.isCompleted, true);
      expect(deserialized.priority, 'high');
    });

    test('deserializes tolerant web payload fields', () {
      final webJson = {
        'id': 42,
        'text': 'Web remote task payload',
        'completed': true,
        'priority': 'normal',
      };

      final item = TaskItem.fromJson(webJson);
      expect(item.id, '42');
      expect(item.title, 'Web remote task payload');
      expect(item.isCompleted, true);
      expect(item.priority, 'normal');
    });
  });

  group('TasksCard Widget', () {
    testWidgets('renders header, title, and empty state when empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(() => _TestTasksNotifier([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: TasksCard(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('Tap + to add a task or priority.'), findsOneWidget);
    });

    testWidgets('renders populated task items with interactive checkboxes',
        (WidgetTester tester) async {
      final notifier = _TestTasksNotifier([
        TaskItem(
          id: '1',
          title: 'Review PR changes',
          isCompleted: false,
          priority: 'high',
          createdAt: DateTime.now(),
        ),
        TaskItem(
          id: '2',
          title: 'Push branch updates',
          isCompleted: true,
          priority: 'normal',
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 400,
                child: TasksCard(currentSize: CardSize.medium),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Review PR changes'), findsOneWidget);
      expect(find.text('Push branch updates'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);

      // Tap on incomplete task to toggle.
      await tester.tap(find.text('Review PR changes'));
      await tester.pump();

      expect(notifier.state.first.isCompleted, true);
    });

    testWidgets(
        'renders small multiline layout and allows deleting tasks with custom font size',
        (WidgetTester tester) async {
      final notifier = _TestTasksNotifier([
        TaskItem(
          id: '1',
          title: 'Multiline Small Card Task',
          isCompleted: false,
          priority: 'high',
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksProvider.overrideWith(() => notifier),
            appSettingsProvider.overrideWith(
              () => _TestAppSettingsNotifier(
                const AppSettingsConfig(cardFontSize: 18.0),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 380,
                child: TasksCard(currentSize: CardSize.small),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Multiline Small Card Task'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify custom font size and softWrap are applied
      final textWidget = tester.widget<Text>(find.text('Multiline Small Card Task'));
      expect(textWidget.style?.fontSize, 18.0);
      expect(textWidget.softWrap, true);

      // Verify delete button has circular 28x28 styling matching CardEditButton
      final deleteIconFinder = find.byIcon(Icons.close_rounded);
      expect(deleteIconFinder, findsOneWidget);
      final containerFinder = find.ancestor(
        of: deleteIconFinder,
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(containerWidget.constraints?.maxWidth, 28);
      expect(containerWidget.constraints?.maxHeight, 28);
      expect(boxDecoration.shape, BoxShape.circle);

      // Tap delete button to remove task
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(notifier.state.isEmpty, true);
    });
  });
}

class _TestTasksNotifier extends TasksNotifier {
  final List<TaskItem> initial;
  _TestTasksNotifier(this.initial);

  @override
  List<TaskItem> build() => initial;

  @override
  void addTask(String title, {String priority = 'normal'}) {
    state = [
      ...state,
      TaskItem(
        id: (state.length + 1).toString(),
        title: title,
        priority: priority,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  void toggleTask(String id) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(isCompleted: !task.isCompleted);
      }
      return task;
    }).toList();
  }

  @override
  void deleteTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

class _TestAppSettingsNotifier extends AppSettingsNotifier {
  final AppSettingsConfig initial;
  _TestAppSettingsNotifier(this.initial);

  @override
  AppSettingsConfig build() => initial;
}
