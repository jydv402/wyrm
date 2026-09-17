import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/server/server.dart';
import 'package:wyrm_desk/settings/settings_state.dart';

void main() {
  group('ShelfWebServer REST and WebSocket tests', () {
    late ShelfWebServer server;
    late CardLayoutConfig activeLayout;
    late AppSettingsConfig activeSettings;

    setUp(() async {
      activeLayout = const CardLayoutConfig();
      activeSettings = const AppSettingsConfig();

      server = ShelfWebServer(
        getLayoutConfig: () => activeLayout,
        getSettingsConfig: () => activeSettings,
        onSetCardSize: (type, size) {
          activeLayout = activeLayout.withSize(type, size);
        },
        onSet24HourFormat: (is24Hour) {
          activeSettings = activeSettings.copyWith(is24HourFormat: is24Hour);
        },
        htmlOverride: '<!DOCTYPE html><html><body>Wyrm Web Test</body></html>',
        cssOverride: 'body { background: #000; }',
        jsOverride: 'console.log("Wyrm JS");',
      );

      // Start on ephemeral port for reliable testing.
      await server.start(port: 0);
    });

    tearDown(() async {
      await server.stop();
    });

    test('GET / serves HTML index client', () async {
      final response = await http.get(Uri.parse('http://127.0.0.1:${server.port}/'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.body, contains('Wyrm Web Test'));
    });

    test('GET /style.css serves CSS stylesheet with text/css MIME', () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/style.css'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/css'));
      expect(response.body, contains('background: #000'));
    });

    test('GET /app.js serves JavaScript logic with application/javascript MIME',
        () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/app.js'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/javascript'));
      expect(response.body, contains('Wyrm JS'));
    });

    test('GET /api/status returns JSON snapshot of layout and settings', () async {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:${server.port}/api/status'));
      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['status'], 'online');
      expect(data['layout']['clock'], 'small');
      expect(data['settings']['is24HourFormat'], false);
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

    test('WebSocket connection receives initial snapshot and accepts commands',
        () async {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );

      // Await initial snapshot.
      final firstMessage = await channel.stream.first;
      final snapshot = jsonDecode(firstMessage.toString()) as Map<String, dynamic>;
      expect(snapshot['type'], 'snapshot');
      expect(snapshot['layout']['clock'], 'small');

      // Send set_layout message over WebSocket.
      channel.sink.add(jsonEncode({
        'type': 'set_layout',
        'card': 'habits',
        'size': 'fullscreen',
      }));

      // Allow event processing.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeLayout.habits, CardSize.fullscreen);

      await channel.sink.close();
    });

    test('NetworkInfo resolves an IPv4 address', () async {
      final ip = await NetworkInfo.getLocalIpAddress();
      expect(ip, isNotEmpty);
      expect(ip.split('.').length, 4);
    });

    test('Redesigned assets/web files contain required components and styling', () async {
      final htmlFile = File('assets/web/index.html');
      final cssFile = File('assets/web/style.css');
      final jsFile = File('assets/web/app.js');

      expect(await htmlFile.exists(), isTrue);
      expect(await cssFile.exists(), isTrue);
      expect(await jsFile.exists(), isTrue);

      final html = await htmlFile.readAsString();
      expect(html, contains('page-switcher'));
      expect(html, contains('header-logo'));
      expect(html, contains('cards-stream'));
      expect(html, contains('card-clock'));
      expect(html, contains('card-habits'));
      expect(html, contains('card-calendar'));
      expect(html, contains('card-tasks'));

      final css = await cssFile.readAsString();
      expect(css, contains('--accent-amber: #ff9500'));
      expect(css, contains('.page-switcher'));
      expect(css, contains('.layout-card'));
      expect(css, contains('.segmented-bar'));

      final js = await jsFile.readAsString();
      expect(js, contains('WyrmStateStore'));
      expect(js, contains('WyrmWebSocketManager'));
      expect(js, contains('WyrmUiRenderer'));
      expect(js, contains('setCardFilter'));
      expect(js, contains('toggleTimeFormat'));
    });
  });
}
