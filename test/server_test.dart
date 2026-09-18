import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
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

    setUp(() async {
      activeLayout = const CardLayoutConfig();
      activeSettings = const AppSettingsConfig();
      activeTasks = [
        TaskItem(
          id: '1',
          title: 'Initial Test Task',
          isCompleted: false,
          priority: 'high',
          createdAt: DateTime.now(),
        ),
      ];

      server = ShelfWebServer(
        getLayoutConfig: () => activeLayout,
        getSettingsConfig: () => activeSettings,
        getTasksConfig: () => activeTasks,
        onSetCardSize: (type, size) {
          activeLayout = activeLayout.withSize(type, size);
        },
        onSet24HourFormat: (is24Hour) {
          activeSettings = activeSettings.copyWith(is24HourFormat: is24Hour);
        },
        onSetCardFontSize: (fontSize) {
          activeSettings = activeSettings.copyWith(cardFontSize: fontSize);
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
      expect(snapshot['tasks'], isList);

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

      // Send create_task message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'create_task',
        'title': 'WebSocket Generated Task',
        'priority': 'normal',
      }));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeTasks.any((t) => t.title == 'WebSocket Generated Task'), true);

      await channel.sink.close();
    });

    test('NetworkInfo resolves an IPv4 address', () async {
      final ip = await NetworkInfo.getLocalIpAddress();
      expect(ip, isNotEmpty);
      expect(ip.split('.').length, 4);
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
      expect(html, contains('card-clock'));
      expect(html, contains('card-habits'));
      expect(html, contains('card-calendar'));
      expect(html, contains('card-tasks'));
      expect(html, contains('taskInput'));
      expect(html, contains('fontSizeDisplay'));
      expect(html, contains('card-detail-section'));

      final css = await cssFile.readAsString();
      expect(css, contains('--accent-amber: #ff9500'));
      expect(css, contains('.task-manager-section'));
      expect(css, contains('.task-item-row'));
      expect(css, contains('.stepper-control'));
      expect(css, contains('.card-detail-section'));

      final js = await jsFile.readAsString();
      expect(js, contains('WyrmStateStore'));
      expect(js, contains('WyrmWebSocketManager'));
      expect(js, contains('WyrmUiRenderer'));
      expect(js, contains('createTask'));
      expect(js, contains('toggleTask'));
      expect(js, contains('deleteTask'));
      expect(js, contains('incrementFontSize'));
      expect(js, contains('data-active-page'));
    });
  });
}
