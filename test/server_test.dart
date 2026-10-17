import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:wyrm_desk/calendar/calendar_model.dart';
import 'package:wyrm_desk/calendar/calendar_state.dart';
import 'package:wyrm_desk/display/display.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/server/server.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';

void main() {
  group('ShelfWebServer REST and WebSocket tests', () {
    late ShelfWebServer server;
    late CardLayoutConfig activeLayout;
    late AppSettingsConfig activeSettings;
    late List<TaskItem> activeTasks;
    late List<CalendarMilestone> activeMilestones;
    late List<HabitItem> activeHabits;
    late DisplayState activeDisplay;
    DashboardCardType? lastScrolledCard;

    setUp(() async {
      activeLayout = const CardLayoutConfig();
      activeSettings = const AppSettingsConfig();
      activeDisplay = const DisplayState();
      lastScrolledCard = null;
      activeHabits = [
        HabitItem(
          id: 'h_1',
          title: 'Initial Habit',
          type: HabitType.numeric,
          targetValue: 8,
          unit: 'cups',
          completions: {'2026-09-20': 4},
          createdAt: DateTime.now(),
        ),
      ];
      activeTasks = [
        TaskItem(
          id: '1',
          title: 'Initial Test Task',
          isCompleted: false,
          priority: 'high',
          createdAt: DateTime.now(),
        ),
      ];
      activeMilestones = [
        CalendarMilestone(
          id: 'ms_1',
          title: 'Initial Test Milestone',
          targetDate: DateTime(2026, 10, 1),
          isPinned: true,
          createdAt: DateTime.now(),
        ),
      ];

      server = ShelfWebServer(
        getLayoutConfig: () => activeLayout,
        getSettingsConfig: () => activeSettings,
        getTasksConfig: () => activeTasks,
        getCalendarConfig: () => CalendarState(
          selectedDate: DateTime(2026, 9, 19),
          viewMonth: DateTime(2026, 9, 1),
          milestones: activeMilestones,
        ),
        getHabitsConfig: () => HabitsState(habits: activeHabits),
        getDisplayConfig: () => activeDisplay,
        onSetCardSize: (type, size) {
          activeLayout = activeLayout.withSize(type, size);
        },
        onSet24HourFormat: (is24Hour) {
          activeSettings = activeSettings.copyWith(is24HourFormat: is24Hour);
        },
        onSetBrightness: (brightness) {
          activeDisplay = activeDisplay.copyWith(brightness: brightness);
        },
        onSetCardFontSize: (fontSize) {
          activeSettings = activeSettings.copyWith(cardFontSize: fontSize);
        },
        onSetStartWeekOnMonday: (startMon) {
          activeSettings = activeSettings.copyWith(startWeekOnMonday: startMon);
        },
        onAddTask: (title, priority) {
          activeTasks = [
            ...activeTasks,
            TaskItem(
              id: (activeTasks.length + 1).toString(),
              title: title,
              priority: priority,
              createdAt: DateTime.now(),
            ),
          ];
        },
        onToggleTask: (id) {
          activeTasks = activeTasks
              .map((t) =>
                  t.id == id ? t.copyWith(isCompleted: !t.isCompleted) : t)
              .toList();
        },
        onDeleteTask: (id) {
          activeTasks = activeTasks.where((t) => t.id != id).toList();
        },
        onAddMilestone: (title, date, {isPinned = false}) {
          activeMilestones = [
            ...activeMilestones,
            CalendarMilestone(
              id: (activeMilestones.length + 1).toString(),
              title: title,
              targetDate: date,
              isPinned: isPinned,
              createdAt: DateTime.now(),
            ),
          ];
        },
        onDeleteMilestone: (id) {
          activeMilestones = activeMilestones.where((m) => m.id != id).toList();
        },
        onTogglePinMilestone: (id) {
          activeMilestones = activeMilestones.map((m) {
            if (m.id == id) return m.copyWith(isPinned: !m.isPinned);
            return m;
          }).toList();
        },
        onAddHabit: (title, type, targetValue, {unit, iconName}) {
          activeHabits = [
            ...activeHabits,
            HabitItem(
              id: (activeHabits.length + 1).toString(),
              title: title,
              type: type,
              targetValue: targetValue,
              unit: unit,
              iconName: iconName ?? 'bolt',
              createdAt: DateTime.now(),
            ),
          ];
        },
        onToggleHabit: (id, [date]) {
          final d = date ?? DateTime.now();
          final k = HabitItem.dateKey(d);
          activeHabits = activeHabits.map((h) {
            if (h.id != id) return h;
            final count = h.completionCountOn(d);
            final newCompletions = Map<String, int>.from(h.completions);
            if (count >= h.targetValue) {
              newCompletions.remove(k);
            } else {
              newCompletions[k] = h.targetValue;
            }
            return h.copyWith(completions: newCompletions);
          }).toList();
        },
        onStepHabit: (id, delta, [date]) {
          final d = date ?? DateTime.now();
          final k = HabitItem.dateKey(d);
          activeHabits = activeHabits.map((h) {
            if (h.id != id) return h;
            final count = h.completionCountOn(d);
            final newCompletions = Map<String, int>.from(h.completions);
            newCompletions[k] = count + delta;
            return h.copyWith(completions: newCompletions);
          }).toList();
        },
        onDeleteHabit: (id) {
          activeHabits = activeHabits.where((h) => h.id != id).toList();
        },
        onScrollToCard: (card) {
          lastScrolledCard = card;
        },
        htmlOverride: '<!DOCTYPE html><html><body>Wyrm Web Test</body></html>',
        cssOverride: 'body { background: #000; }',
        jsOverride: 'console.log("Wyrm JS");',
        faviconOverride: [137, 80, 78, 71, 13, 10, 26, 10],
      );

      // Start on ephemeral port for reliable testing.
      await server.start(port: 0);
    });

    tearDown(() async {
      await server.stop();
    });

    test('GET / serves HTML index client', () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.body, contains('Wyrm Web Test'));
    });

    test('GET /style.css serves CSS stylesheet with text/css MIME', () async {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:${server.port}/style.css'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/css'));
      expect(response.body, contains('background: #000'));
    });

    test('GET /app.js serves JavaScript logic with application/javascript MIME',
        () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/app.js'));
      expect(response.statusCode, 200);
      expect(
          response.headers['content-type'], contains('application/javascript'));
      expect(response.body, contains('Wyrm JS'));
    });

    test('GET /favicon.ico serves favicon with image/png MIME', () async {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:${server.port}/favicon.ico'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('image/png'));
      expect(response.bodyBytes, equals([137, 80, 78, 71, 13, 10, 26, 10]));
    });

    test('GET /assets/icons/icon_flat.png serves favicon with image/png MIME',
        () async {
      final response = await http.get(Uri.parse(
          'http://127.0.0.1:${server.port}/assets/icons/icon_flat.png'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('image/png'));
      expect(response.bodyBytes, equals([137, 80, 78, 71, 13, 10, 26, 10]));
    });

    test('GET /api/status returns JSON snapshot of layout, settings, and tasks',
        () async {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:${server.port}/api/status'));
      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['status'], 'online');
      expect(data['layout']['clock'], 'small');
      expect(data['settings']['is24HourFormat'], false);
      expect(data['settings']['cardFontSize'], 14.0);
      expect(data['tasks'], isList);
      expect((data['tasks'] as List).length, 1);
    });

    test('GET /api/tasks returns active task list', () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/api/tasks'));
      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as List;
      expect(data.length, 1);
      expect(data.first['title'], 'Initial Test Task');
    });

    test('POST /api/tasks adds a new task item', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': 'New Remote Task', 'priority': 'high'}),
      );

      expect(response.statusCode, 200);
      expect(activeTasks.length, 2);
      expect(activeTasks.last.title, 'New Remote Task');
      expect(activeTasks.last.priority, 'high');
    });

    test('POST /api/tasks/toggle toggles task completion status', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': '1'}),
      );

      expect(response.statusCode, 200);
      expect(activeTasks.first.isCompleted, true);
    });

    test('POST /api/tasks/delete removes a task item', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': '1'}),
      );

      expect(response.statusCode, 200);
      expect(activeTasks.isEmpty, true);
    });

    test('POST /api/layout updates card size accurately', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/layout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card': 'clock', 'size': 'nightstand'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeLayout.clock, CardSize.nightstand);
      expect(lastScrolledCard, DashboardCardType.clock);
    });

    test('POST /api/scroll triggers onScrollToCard with valid card', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/scroll'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card': 'tasks'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(data['card'], 'tasks');
      expect(lastScrolledCard, DashboardCardType.tasks);
    });

    test('POST /api/scroll returns 400 for invalid card', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/scroll'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card': 'non_existent_card'}),
      );

      expect(response.statusCode, 400);
    });

    test('POST /api/settings updates 24-hour time format', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'is24HourFormat': true}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeSettings.is24HourFormat, true);
    });

    test('POST /api/settings updates card font size', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cardFontSize': 18.0}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeSettings.cardFontSize, 18.0);
    });

    test('POST /api/settings updates startWeekOnMonday setting', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'startWeekOnMonday': true}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeSettings.startWeekOnMonday, true);
    });

    test('GET /api/status includes display state and habits', () async {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:${server.port}/api/status'));
      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['display'], isMap);
      expect(data['display']['brightness'], 1.0);
      expect(data['habits'], isList);
      expect((data['habits'] as List).length, 1);
    });

    test('GET /api/display returns the active display state', () async {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:${server.port}/api/display'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['brightness'], 1.0);
    });

    test('POST /api/display updates brightness', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/display'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'brightness': 0.4}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeDisplay.brightness, closeTo(0.4, 0.0001));
    });

    test('POST /api/display returns 400 for empty payload', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/display'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      expect(response.statusCode, 400);
    });

    test('GET /api/calendar returns active milestones and metrics', () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/api/calendar'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data.containsKey('yearProgress'), true);
      expect(data.containsKey('quarterProgress'), true);
      expect(data.containsKey('milestones'), true);

      final milestones = data['milestones'] as List;
      expect(milestones.isNotEmpty, true);
      expect(milestones.first['title'], 'Initial Test Milestone');
    });

    test('POST /api/calendar/milestones creates a new milestone', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar/milestones'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'New Vacation',
          'target_date': '2026-12-25',
          'is_pinned': false,
        }),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeMilestones.any((m) => m.title == 'New Vacation'), true);
    });

    test('POST /api/calendar/milestones/pin toggles milestone pin state', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar/milestones/pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'ms_1'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeMilestones.firstWhere((m) => m.id == 'ms_1').isPinned, false);
    });

    test('POST /api/calendar/milestones/delete removes a milestone item', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar/milestones/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'ms_1'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeMilestones.any((m) => m.id == 'ms_1'), false);
    });

    test('WebSocket connection receives initial snapshot and accepts commands',
        () async {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );

      // Await initial snapshot.
      final firstMessage = await channel.stream.first;
      final snapshot =
          jsonDecode(firstMessage.toString()) as Map<String, dynamic>;
      expect(snapshot['type'], 'snapshot');
      expect(snapshot['layout']['clock'], 'small');
      expect(snapshot['settings']['cardFontSize'], 14.0);
      expect(snapshot['display']['brightness'], 1.0);
      expect(snapshot['tasks'], isList);
      expect(snapshot['calendar'], isMap);

      // Send set_layout message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'set_layout',
        'card': 'habits',
        'size': 'fullscreen',
      }));

      // Allow event processing.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeLayout.habits, CardSize.fullscreen);

      // Send set_settings message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'set_settings',
        'cardFontSize': 20.0,
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeSettings.cardFontSize, 20.0);

      // Send set_display message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'set_display',
        'brightness': 0.35,
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeDisplay.brightness, closeTo(0.35, 0.0001));

      // Send create_task message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'create_task',
        'title': 'WebSocket Generated Task',
        'priority': 'normal',
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeTasks.any((t) => t.title == 'WebSocket Generated Task'), true);

      // Send create_milestone message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'create_milestone',
        'title': 'WS Milestone',
        'targetDate': '2026-11-15',
        'isPinned': true,
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeMilestones.any((m) => m.title == 'WS Milestone'), true);

      // Send scroll_to_card message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'scroll_to_card',
        'card': 'habits',
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(lastScrolledCard, DashboardCardType.habits);

      await channel.sink.close();
    });

    test('NetworkInfo resolves an IPv4 address', () async {
      final ip = await NetworkInfo.getLocalIpAddress();
      expect(ip, isNotEmpty);
      expect(ip.split('.').length, 4);
    });

    test('GET /api/habits returns active habit list', () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/api/habits'));
      expect(response.statusCode, 200);

      final List decoded = jsonDecode(response.body);
      expect(decoded.length, 1);
      expect(decoded.first['title'], 'Initial Habit');
      expect(decoded.first['target_value'], 8);
    });

    test('POST /api/habits adds a new habit', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Read 10 Pages',
          'type': 'numeric',
          'target_value': 10,
          'unit': 'pages',
          'icon_name': 'menu_book',
        }),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.length, 2);
      expect(activeHabits.last.title, 'Read 10 Pages');
      expect(activeHabits.last.unit, 'pages');
    });

    test('POST /api/habits supports habit_type and glyph aliases', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Sprint Practice',
          'habit_type': 'binary',
          'glyph': 'run',
        }),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.last.title, 'Sprint Practice');
      expect(activeHabits.last.type, HabitType.binary);
      expect(activeHabits.last.iconName, 'run');
    });

    test('WebSocket create_habit creates habit with custom glyph', () async {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );

      await channel.stream.first;

      channel.sink.add(jsonEncode({
        'type': 'create_habit',
        'title': 'Evening Journal',
        'habit_type': 'binary',
        'icon_name': 'book',
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeHabits.any((h) => h.title == 'Evening Journal'), isTrue);
      expect(activeHabits.firstWhere((h) => h.title == 'Evening Journal').iconName, 'book');

      await channel.sink.close();
    });

    test('POST /api/habits/toggle toggles habit completion', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': 'h_1',
          'date': '2026-09-20',
        }),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.first.isCompletedOn(DateTime(2026, 9, 20)), isTrue);
    });

    test('POST /api/habits/step increments habit count', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits/step'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': 'h_1',
          'delta': 2,
          'date': '2026-09-20',
        }),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.first.completionCountOn(DateTime(2026, 9, 20)), 6);
    });

    test('POST /api/habits/delete removes a habit', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'h_1'}),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.where((h) => h.id == 'h_1'), isEmpty);
    });

    test('Redesigned assets/web files contain required components and styling',
        () async {
      final htmlFile = File('assets/web/index.html');
      final cssFile = File('assets/web/style.css');
      final jsFile = File('assets/web/app.js');

      expect(await htmlFile.exists(), isTrue);
      expect(await cssFile.exists(), isTrue);
      expect(await jsFile.exists(), isTrue);

      final html = await htmlFile.readAsString();
      expect(html, contains('header-brand'));
      expect(html, contains('card-all'));
      expect(html, contains('card-clock'));
      expect(html, contains('card-habits'));
      expect(html, contains('card-habits-tracker'));
      expect(html, contains('habitGlyphPicker'));
      expect(html, contains('glyph-chip'));
      expect(html, contains('card-calendar'));
      expect(html, contains('card-tasks'));
      expect(html, contains('card-calendar-weekstart'));
      expect(html, contains('card-calendar-progress'));
      expect(html, contains('card-calendar-grid'));
      expect(html, contains('card-calendar-milestones'));
      expect(html, contains('milestone-date-container'));
      expect(html, contains('placeholder="dd/mm/yyyy"'));
      expect(html, contains('milestone-picker-trigger'));
      expect(html, contains('card-display-brightness'));
      expect(html, contains('brightnessSlider'));

      final css = await cssFile.readAsString();
      expect(css, contains('--accent-amber: #ff9500'));
      expect(css, contains('.task-manager-section'));
      expect(css, contains('.habit-manager-section'));
      expect(css, contains('.glyph-picker-container'));
      expect(css, contains('.glyph-chip'));
      expect(css, contains('.progress-section'));
      expect(css, contains('.web-calendar-container'));
      expect(css, contains('.milestone-manager-section'));
      expect(css, contains('.milestone-date-container'));
      expect(css, contains('.milestone-picker-trigger'));
      expect(css, contains('.card-tapped'));
      expect(css, contains('.brightness-slider'));

      final js = await jsFile.readAsString();
      expect(js, contains('WyrmStateStore'));
      expect(js, contains('WyrmWebSocketManager'));
      expect(js, contains('WyrmUiRenderer'));
      expect(js, contains('setAllCardsSize'));
      expect(js, contains('toggleStartWeekOnMonday'));
      expect(js, contains('createMilestone'));
      expect(js, contains('deleteMilestone'));
      expect(js, contains('togglePinMilestone'));
      expect(js, contains('pickMilestoneDate'));
      expect(js, contains('onMilestonePickerChange'));
      expect(js, contains('createHabit'));
      expect(js, contains('selectHabitGlyph'));
      expect(js, contains('selectedHabitGlyph'));
      expect(js, contains('toggleHabit'));
      expect(js, contains('stepHabit'));
      expect(js, contains('deleteHabit'));
      expect(js, contains('scrollToCard'));
      expect(js, contains('setBrightness'));
      expect(js, contains(r'${day}/${month}/${year}'));
    });

    test('POST /api/calendar/milestones accepts dd/mm/yyyy date format', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar/milestones'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Christmas Launch',
          'target_date': '25/12/2026',
          'is_pinned': true,
        }),
      );
      expect(response.statusCode, 200);
      final created = activeMilestones.firstWhere((m) => m.title == 'Christmas Launch');
      expect(created.targetDate.year, 2026);
      expect(created.targetDate.month, 12);
      expect(created.targetDate.day, 25);
      expect(created.isPinned, isTrue);
    });
  });
}
