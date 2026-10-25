import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wyrm_desk/calendar/calendar_state.dart';
import 'package:wyrm_desk/display/display_state.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';

/// Embedded Shelf HTTP and WebSocket server hosting the remote web companion.
class ShelfWebServer {
  /// Default TCP port for local tablet remote hosting.
  static const int defaultPort = 8080;

  final CardLayoutConfig Function() getLayoutConfig;
  final AppSettingsConfig Function() getSettingsConfig;
  final List<TaskItem> Function()? getTasksConfig;
  final CalendarState Function()? getCalendarConfig;
  final HabitsState Function()? getHabitsConfig;
  final DisplayState Function()? getDisplayConfig;
  final void Function(DashboardCardType type, CardSize size) onSetCardSize;
  final void Function(bool is24Hour) onSet24HourFormat;
  final void Function(double fontSize)? onSetCardFontSize;
  final void Function(bool startWeekOnMonday)? onSetStartWeekOnMonday;
  final void Function(double brightness)? onSetBrightness;
  final void Function(String title, String priority)? onAddTask;
  final void Function(String id)? onToggleTask;
  final void Function(String id)? onDeleteTask;
  final void Function(String title, DateTime targetDate, {bool isPinned})? onAddMilestone;
  final void Function(String id)? onDeleteMilestone;
  final void Function(String id)? onTogglePinMilestone;
  final void Function(String title, HabitType type, int targetValue, {String? unit, String? iconName})? onAddHabit;
  final void Function(String id, [DateTime? date])? onToggleHabit;
  final void Function(String id, int delta, [DateTime? date])? onStepHabit;
  final void Function(String id)? onDeleteHabit;
  final void Function(DashboardCardType card)? onScrollToCard;

  /// Optional asset content overrides for headless testing environments.
  final String? htmlOverride;
  final String? cssOverride;
  final String? jsOverride;
  final List<int>? faviconOverride;

  HttpServer? _server;
  final Set<WebSocketChannel> _activeClients = <WebSocketChannel>{};

  ShelfWebServer({
    required this.getLayoutConfig,
    required this.getSettingsConfig,
    this.getTasksConfig,
    this.getCalendarConfig,
    this.getHabitsConfig,
    this.getDisplayConfig,
    required this.onSetCardSize,
    required this.onSet24HourFormat,
    this.onSetCardFontSize,
    this.onSetStartWeekOnMonday,
    this.onSetBrightness,
    this.onAddTask,
    this.onToggleTask,
    this.onDeleteTask,
    this.onAddMilestone,
    this.onDeleteMilestone,
    this.onTogglePinMilestone,
    this.onAddHabit,
    this.onToggleHabit,
    this.onStepHabit,
    this.onDeleteHabit,
    this.onScrollToCard,
    this.htmlOverride,
    this.cssOverride,
    this.jsOverride,
    this.faviconOverride,
  });

  /// Starts the embedded HTTP and WebSocket server on the designated port.
  Future<HttpServer> start({int port = defaultPort}) async {
    final router = Router();

    // Serve web remote client application assets.
    router.get('/', _handleIndexHtml);
    router.get('/index.html', _handleIndexHtml);
    router.get('/style.css', _handleStyleCss);
    router.get('/app.js', _handleAppJs);
    router.get('/favicon.ico', _handleFavicon);
    router.get('/icon_flat.png', _handleFavicon);
    router.get('/assets/icons/icon_flat.png', _handleFavicon);
    router.get('/assets/web/<file|.*>', _handleStaticAsset);
    router.get('/<file|.*\\.(?:js|css|png|svg|json|webmanifest|ico|woff2?)>', _handleStaticAsset);

    // REST API endpoints.
    router.get('/api/status', _handleGetStatus);
    router.post('/api/layout', _handlePostLayout);
    router.post('/api/scroll', _handlePostScroll);
    router.post('/api/settings', _handlePostSettings);
    router.get('/api/display', _handleGetDisplay);
    router.post('/api/display', _handlePostDisplay);
    router.get('/api/tasks', _handleGetTasks);
    router.post('/api/tasks', _handlePostTask);
    router.post('/api/tasks/toggle', _handlePostToggleTask);
    router.post('/api/tasks/delete', _handlePostDeleteTask);
    router.get('/api/calendar', _handleGetCalendar);
    router.post('/api/calendar/milestones', _handlePostAddMilestone);
    router.post('/api/calendar/milestones/delete', _handlePostDeleteMilestone);
    router.post('/api/calendar/milestones/pin', _handlePostPinMilestone);
    router.get('/api/habits', _handleGetHabits);
    router.post('/api/habits', _handlePostAddHabit);
    router.post('/api/habits/toggle', _handlePostToggleHabit);
    router.post('/api/habits/step', _handlePostStepHabit);
    router.post('/api/habits/delete', _handlePostDeleteHabit);

    // WebSocket real-time channel.
    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel webSocket, [String? protocol]) {
        _handleWebSocketConnection(webSocket);
      }),
    );

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
    );

    return _server!;
  }

  /// Gracefully closes all active client connections and terminates the HTTP server.
  Future<void> stop() async {
    for (final client in _activeClients.toList()) {
      try {
        await client.sink.close();
      } catch (_) {}
    }
    _activeClients.clear();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// Active port the server is listening on, or null if stopped.
  int? get port => _server?.port;

  /// Number of active WebSocket clients connected to the server.
  int get connectedClientsCount => _activeClients.length;

  /// Broadcasts updated layout, settings, task, calendar, and habit state to all connected WebSocket clients.
  void broadcastState({
    CardLayoutConfig? layout,
    AppSettingsConfig? settings,
    List<TaskItem>? tasks,
    CalendarState? calendar,
    HabitsState? habits,
    DisplayState? display,
  }) {
    final activeLayout = layout ?? getLayoutConfig();
    final activeSettings = settings ?? getSettingsConfig();
    final activeTasks =
        tasks ?? (getTasksConfig != null ? getTasksConfig!() : <TaskItem>[]);
    final activeCalendar =
        calendar ?? (getCalendarConfig != null ? getCalendarConfig!() : null);
    final activeHabits =
        habits ?? (getHabitsConfig != null ? getHabitsConfig!() : const HabitsState());
    final activeDisplay =
        display ?? (getDisplayConfig != null ? getDisplayConfig!() : const DisplayState());

    final payload = jsonEncode({
      'type': 'state_update',
      'layout': activeLayout.toJson(),
      'settings': {
        'is24HourFormat': activeSettings.is24HourFormat,
        'cardFontSize': activeSettings.cardFontSize,
        'startWeekOnMonday': activeSettings.startWeekOnMonday,
      },
      'display': activeDisplay.toWireJson(),
      'tasks': activeTasks.map((t) => t.toJson()).toList(),
      'calendar': _serializeCalendarState(activeCalendar, activeSettings.startWeekOnMonday),
      'habits': activeHabits.habits.map((h) => h.toJson()).toList(),
    });

    for (final client in _activeClients.toList()) {
      try {
        client.sink.add(payload);
      } catch (_) {
        _activeClients.remove(client);
      }
    }
  }

  /// Handles incoming WebSocket client connections.
  void _handleWebSocketConnection(WebSocketChannel webSocket) {
    _activeClients.add(webSocket);

    final activeTasks =
        getTasksConfig != null ? getTasksConfig!() : <TaskItem>[];
    final activeCalendar =
        getCalendarConfig != null ? getCalendarConfig!() : null;
    final activeHabits =
        getHabitsConfig != null ? getHabitsConfig!() : const HabitsState();

    // Send immediate state snapshot upon connection.
    final initialSnapshot = jsonEncode({
      'type': 'snapshot',
      'layout': getLayoutConfig().toJson(),
      'settings': {
        'is24HourFormat': getSettingsConfig().is24HourFormat,
        'cardFontSize': getSettingsConfig().cardFontSize,
        'startWeekOnMonday': getSettingsConfig().startWeekOnMonday,
      },
      'display': (getDisplayConfig != null ? getDisplayConfig!() : const DisplayState()).toWireJson(),
      'tasks': activeTasks.map((t) => t.toJson()).toList(),
      'calendar': _serializeCalendarState(activeCalendar, getSettingsConfig().startWeekOnMonday),
      'habits': activeHabits.habits.map((h) => h.toJson()).toList(),
    });

    try {
      webSocket.sink.add(initialSnapshot);
    } catch (_) {}

    webSocket.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString()) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'set_layout') {
            final cardName = data['card'] as String?;
            final sizeName = data['size'] as String?;
            if (cardName != null && sizeName != null) {
              _applyCardSize(cardName, sizeName);
            }
          } else if (type == 'set_settings') {
            if (data.containsKey('is24HourFormat')) {
              final is24Hour = data['is24HourFormat'] as bool;
              onSet24HourFormat(is24Hour);
            }
            if (data.containsKey('cardFontSize') && onSetCardFontSize != null) {
              final size = (data['cardFontSize'] as num).toDouble();
              onSetCardFontSize!(size);
            }
            if (data.containsKey('startWeekOnMonday') && onSetStartWeekOnMonday != null) {
              final startMon = data['startWeekOnMonday'] as bool;
              onSetStartWeekOnMonday!(startMon);
            }
          } else if (type == 'set_display') {
            if (data.containsKey('brightness') && onSetBrightness != null) {
              final raw = data['brightness'];
              final brightness =
                  raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
              if (brightness != null) {
                onSetBrightness!(brightness);
              }
            }
          } else if (type == 'create_task') {
            final title = data['title'] as String?;
            final priority = (data['priority'] as String?) ?? 'normal';
            if (title != null && title.trim().isNotEmpty && onAddTask != null) {
              onAddTask!(title.trim(), priority);
            }
          } else if (type == 'toggle_task') {
            final id = data['id']?.toString();
            if (id != null && onToggleTask != null) {
              onToggleTask!(id);
            }
          } else if (type == 'delete_task') {
            final id = data['id']?.toString();
            if (id != null && onDeleteTask != null) {
              onDeleteTask!(id);
            }
          } else if (type == 'create_milestone') {
            final title = data['title'] as String?;
            final dateStr = (data['target_date'] ?? data['targetDate'] ?? data['date']) as String?;
            final isPinned = (data['is_pinned'] ?? data['isPinned'] ?? false) as bool;
            if (title != null && title.trim().isNotEmpty && onAddMilestone != null) {
              final targetDate = _parseMilestoneDate(dateStr);
              onAddMilestone!(title.trim(), targetDate, isPinned: isPinned);
            }
          } else if (type == 'delete_milestone') {
            final id = data['id']?.toString();
            if (id != null && onDeleteMilestone != null) {
              onDeleteMilestone!(id);
            }
          } else if (type == 'toggle_pin_milestone') {
            final id = data['id']?.toString();
            if (id != null && onTogglePinMilestone != null) {
              onTogglePinMilestone!(id);
            }
          } else if (type == 'create_habit') {
            final title = (data['title'] ?? data['name']) as String?;
            final typeStr = (data['habit_type'] ?? data['type']) as String?;
            final targetValue = data['target_value'] is num
                ? (data['target_value'] as num).toInt()
                : (int.tryParse(data['target_value']?.toString() ?? '1') ?? 1);
            final unit = data['unit'] as String?;
            final iconName = (data['icon_name'] ?? data['iconName'] ?? data['glyph'] ?? 'bolt').toString();
            if (title != null && title.trim().isNotEmpty && onAddHabit != null) {
              onAddHabit!(
                title.trim(),
                HabitType.fromString(typeStr),
                targetValue,
                unit: unit?.trim().isEmpty == true ? null : unit?.trim(),
                iconName: iconName,
              );
            }
          } else if (type == 'toggle_habit') {
            final id = data['id']?.toString();
            final dateStr = data['date']?.toString();
            final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
            if (id != null && onToggleHabit != null) {
              onToggleHabit!(id, date);
            }
          } else if (type == 'step_habit') {
            final id = data['id']?.toString();
            final delta = data['delta'] is num
                ? (data['delta'] as num).toInt()
                : (int.tryParse(data['delta']?.toString() ?? '1') ?? 1);
            final dateStr = data['date']?.toString();
            final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
            if (id != null && onStepHabit != null) {
              onStepHabit!(id, delta, date);
            }
          } else if (type == 'delete_habit') {
            final id = data['id']?.toString();
            if (id != null && onDeleteHabit != null) {
              onDeleteHabit!(id);
            }
          } else if (type == 'scroll_to_card') {
            final cardName = data['card'] as String?;
            final card = DashboardCardType.tryParse(cardName);
            if (card != null && onScrollToCard != null) {
              onScrollToCard!(card);
            }
          }
        } catch (_) {}
      },
      onDone: () => _activeClients.remove(webSocket),
      onError: (_) => _activeClients.remove(webSocket),
    );
  }

  /// Serves the index HTML document.
  Future<Response> _handleIndexHtml(Request request) async {
    try {
      final html = htmlOverride ??
          await rootBundle.loadString('assets/web/index.html');

      return Response.ok(
        html,
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-cache',
        },
      );
    } catch (_) {
      return Response.ok(
        '<!DOCTYPE html><html><body><h1>WYRM Desk Server Running</h1></body></html>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    }
  }

  /// Serves the modular CSS stylesheet.
  Future<Response> _handleStyleCss(Request request) async {
    try {
      final css = cssOverride ??
          await rootBundle.loadString('assets/web/style.css');

      return Response.ok(
        css,
        headers: {
          'Content-Type': 'text/css; charset=utf-8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
    } catch (_) {
      return Response.notFound('/* CSS asset not found */');
    }
  }

  /// Serves the client JavaScript logic.
  Future<Response> _handleAppJs(Request request) async {
    try {
      final js = jsOverride ??
          await rootBundle.loadString('assets/web/app.js');

      return Response.ok(
        js,
        headers: {
          'Content-Type': 'application/javascript; charset=utf-8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
    } catch (_) {
      return Response.notFound('// JS asset not found');
    }
  }

  /// Determines MIME type based on file path extension.
  static String _getMimeType(String filePath) {
    if (filePath.endsWith('.js')) {
      return 'application/javascript; charset=utf-8';
    } else if (filePath.endsWith('.css')) {
      return 'text/css; charset=utf-8';
    } else if (filePath.endsWith('.html')) {
      return 'text/html; charset=utf-8';
    } else if (filePath.endsWith('.webmanifest')) {
      return 'application/manifest+json; charset=utf-8';
    } else if (filePath.endsWith('.png')) {
      return 'image/png';
    } else if (filePath.endsWith('.svg')) {
      return 'image/svg+xml';
    } else if (filePath.endsWith('.json')) {
      return 'application/json';
    }
    return 'application/octet-stream';
  }

  /// Serves static assets located inside assets/web/ dynamically.
  Future<Response> _handleStaticAsset(Request request) async {
    String filePath = request.url.path;
    if (filePath.startsWith('assets/web/')) {
      filePath = filePath.substring('assets/web/'.length);
    }
    final assetPath = 'assets/web/$filePath';
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final mime = _getMimeType(filePath);

      return Response.ok(
        bytes,
        headers: {
          'Content-Type': mime,
          'Cache-Control': 'public, max-age=86400',
        },
      );
    } catch (_) {
      final file = File(assetPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final mime = _getMimeType(filePath);

        return Response.ok(
          bytes,
          headers: {
            'Content-Type': mime,
            'Cache-Control': 'public, max-age=86400',
          },
        );
      }
      return Response.notFound('Asset not found: $filePath');
    }
  }

  /// Serves the client favicon icon.
  Future<Response> _handleFavicon(Request request) async {
    try {
      if (faviconOverride != null) {
        return Response.ok(
          faviconOverride!,
          headers: {
            'Content-Type': 'image/png',
            'Cache-Control': 'public, max-age=86400',
          },
        );
      }
      final data = await rootBundle.load('assets/icons/icon_flat.png');
      return Response.ok(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        headers: {
          'Content-Type': 'image/png',
          'Cache-Control': 'public, max-age=86400',
        },
      );
    } catch (_) {
      return Response.notFound('Favicon not found');
    }
  }

  /// Returns current system status, card layout, clock settings, tasks, and calendar in JSON.
  Response _handleGetStatus(Request request) {
    final layout = getLayoutConfig();
    final settings = getSettingsConfig();
    final tasks =
        getTasksConfig != null ? getTasksConfig!() : <TaskItem>[];
    final calendar =
        getCalendarConfig != null ? getCalendarConfig!() : null;
    final habits =
        getHabitsConfig != null ? getHabitsConfig!().habits : <HabitItem>[];
    final display =
        getDisplayConfig != null ? getDisplayConfig!() : const DisplayState();

    return Response.ok(
      jsonEncode({
        'status': 'online',
        'layout': layout.toJson(),
        'settings': {
          'is24HourFormat': settings.is24HourFormat,
          'cardFontSize': settings.cardFontSize,
          'startWeekOnMonday': settings.startWeekOnMonday,
        },
        'display': display.toWireJson(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'habits': habits.map((h) => h.toJson()).toList(),
        'calendar': _serializeCalendarState(calendar, settings.startWeekOnMonday),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Returns the current tablet display state (panel power and brightness) in JSON.
  Response _handleGetDisplay(Request request) {
    final display =
        getDisplayConfig != null ? getDisplayConfig!() : const DisplayState();
    return Response.ok(
      jsonEncode(display.toWireJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Mutates the tablet display brightness via REST POST call.
  Future<Response> _handlePostDisplay(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      bool updated = false;
      if (data.containsKey('brightness') && onSetBrightness != null) {
        final raw = data['brightness'];
        final brightness =
            raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
        if (brightness != null) {
          onSetBrightness!(brightness);
          updated = true;
        }
      }

      if (updated) {
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid display payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Serializes calendar state or fallback empty state to a JSON map.
  Map<String, dynamic> _serializeCalendarState(CalendarState? cal, bool startWeekOnMonday) {
    if (cal == null) {
      final now = DateTime.now();
      return {
        'today': now.toIso8601String(),
        'yearProgress': 0.0,
        'quarterProgress': 0.0,
        'dayOfYear': 1,
        'daysInYear': 365,
        'currentQuarter': 1,
        'startWeekOnMonday': startWeekOnMonday,
        'milestones': <dynamic>[],
      };
    }
    return {
      'today': DateTime.now().toIso8601String(),
      'selectedDate': cal.selectedDate.toIso8601String(),
      'viewMonth': cal.viewMonth.toIso8601String(),
      'yearProgress': cal.yearProgress,
      'quarterProgress': cal.quarterProgress,
      'dayOfYear': cal.dayOfYear,
      'daysInYear': cal.daysInYear,
      'currentQuarter': cal.currentQuarter,
      'startWeekOnMonday': startWeekOnMonday,
      'milestones': cal.milestones.map((m) => m.toJson()).toList(),
    };
  }

  /// Returns active calendar metrics and milestones in JSON.
  Response _handleGetCalendar(Request request) {
    final calendar =
        getCalendarConfig != null ? getCalendarConfig!() : null;
    final settings = getSettingsConfig();

    return Response.ok(
      jsonEncode(_serializeCalendarState(calendar, settings.startWeekOnMonday)),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Returns list of active tasks in JSON.
  Response _handleGetTasks(Request request) {
    final tasks =
        getTasksConfig != null ? getTasksConfig!() : <TaskItem>[];

    return Response.ok(
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Creates a new task via REST POST call.
  Future<Response> _handlePostTask(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final title = (data['title'] ?? data['text']) as String?;
      final priority = (data['priority'] as String?) ?? 'normal';

      if (title != null && title.trim().isNotEmpty && onAddTask != null) {
        onAddTask!(title.trim(), priority);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid task payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Toggles task completion status via REST POST call.
  Future<Response> _handlePostToggleTask(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();

      if (id != null && onToggleTask != null) {
        onToggleTask!(id);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid toggle payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Deletes a task via REST POST call.
  Future<Response> _handlePostDeleteTask(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();

      if (id != null && onDeleteTask != null) {
        onDeleteTask!(id);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid delete payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Creates a new calendar milestone via REST POST call.
  Future<Response> _handlePostAddMilestone(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final title = (data['title'] ?? data['text'] ?? data['name']) as String?;
      final dateStr = (data['target_date'] ?? data['targetDate'] ?? data['date']) as String?;
      final isPinned = (data['is_pinned'] ?? data['isPinned'] ?? false) as bool;

      if (title != null && title.trim().isNotEmpty && onAddMilestone != null) {
        final targetDate = _parseMilestoneDate(dateStr);
        onAddMilestone!(title.trim(), targetDate, isPinned: isPinned);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid milestone payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Deletes a calendar milestone via REST POST call.
  Future<Response> _handlePostDeleteMilestone(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();

      if (id != null && onDeleteMilestone != null) {
        onDeleteMilestone!(id);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid delete milestone payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Toggles pinned state for a calendar milestone via REST POST call.
  Future<Response> _handlePostPinMilestone(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();

      if (id != null && onTogglePinMilestone != null) {
        onTogglePinMilestone!(id);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid pin milestone payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Returns full habit registry via REST GET call.
  Future<Response> _handleGetHabits(Request request) async {
    final activeHabits =
        getHabitsConfig != null ? getHabitsConfig!().habits : <HabitItem>[];
    return Response.ok(
      jsonEncode(activeHabits.map((h) => h.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Creates a new habit via REST POST call.
  Future<Response> _handlePostAddHabit(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final title = (data['title'] ?? data['name']) as String?;
      final typeStr = (data['habit_type'] ?? data['type']) as String?;
      final rawTarget = data['target_value'] ?? data['targetValue'] ?? data['target'];
      final targetValue = rawTarget is num
          ? rawTarget.toInt()
          : (int.tryParse(rawTarget?.toString() ?? '1') ?? 1);
      final unit = data['unit'] as String?;
      final iconName = (data['icon_name'] ?? data['iconName'] ?? data['glyph'] ?? 'bolt').toString();

      if (title != null && title.trim().isNotEmpty && onAddHabit != null) {
        onAddHabit!(
          title.trim(),
          HabitType.fromString(typeStr),
          targetValue,
          unit: unit?.trim().isEmpty == true ? null : unit?.trim(),
          iconName: iconName,
        );
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid habit payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Toggles habit completion via REST POST call.
  Future<Response> _handlePostToggleHabit(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();
      final dateStr = (data['date'] ?? data['target_date']) as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

      if (id != null && onToggleHabit != null) {
        onToggleHabit!(id, date);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid toggle habit payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Increments or decrements habit progress count via REST POST call.
  Future<Response> _handlePostStepHabit(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();
      final delta = data['delta'] is num
          ? (data['delta'] as num).toInt()
          : (int.tryParse(data['delta']?.toString() ?? '1') ?? 1);
      final dateStr = (data['date'] ?? data['target_date']) as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

      if (id != null && onStepHabit != null) {
        onStepHabit!(id, delta, date);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid step habit payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Deletes a habit via REST POST call.
  Future<Response> _handlePostDeleteHabit(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final id = data['id']?.toString();

      if (id != null && onDeleteHabit != null) {
        onDeleteHabit!(id);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid delete habit payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Mutates card dimensions via REST POST call.
  Future<Response> _handlePostLayout(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final cardName = data['card'] as String?;
      final sizeName = data['size'] as String?;

      if (cardName != null && sizeName != null) {
        _applyCardSize(cardName, sizeName);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid layout payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Triggers auto-scroll to designated card via REST POST call.
  Future<Response> _handlePostScroll(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final cardName = data['card'] as String?;
      final card = DashboardCardType.tryParse(cardName);

      if (card != null && onScrollToCard != null) {
        onScrollToCard!(card);
        return Response.ok(
          jsonEncode({'success': true, 'card': card.name}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid scroll payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Mutates settings via REST POST call.
  Future<Response> _handlePostSettings(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      bool updated = false;
      if (data.containsKey('is24HourFormat')) {
        final is24Hour = data['is24HourFormat'] as bool;
        onSet24HourFormat(is24Hour);
        updated = true;
      }
      if (data.containsKey('cardFontSize') && onSetCardFontSize != null) {
        final size = (data['cardFontSize'] as num).toDouble();
        onSetCardFontSize!(size);
        updated = true;
      }
      if (data.containsKey('startWeekOnMonday') && onSetStartWeekOnMonday != null) {
        final startMon = data['startWeekOnMonday'] as bool;
        onSetStartWeekOnMonday!(startMon);
        updated = true;
      }

      if (updated) {
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    return Response.badRequest(
      body: jsonEncode({'error': 'Invalid settings payload'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Resolves string tokens to DashboardCardType and CardSize enums and executes callback.
  void _applyCardSize(String cardName, String sizeName) {
    DashboardCardType? targetCard;
    for (final card in DashboardCardType.values) {
      if (card.name.toLowerCase() == cardName.toLowerCase()) {
        targetCard = card;
        break;
      }
    }

    CardSize? targetSize;
    for (final size in CardSize.values) {
      if (size.name.toLowerCase() == sizeName.toLowerCase()) {
        targetSize = size;
        break;
      }
    }

    if (targetCard != null && targetSize != null) {
      onSetCardSize(targetCard, targetSize);
      if (onScrollToCard != null) {
        onScrollToCard!(targetCard);
      }
    }
  }

  /// Tolerantly parses milestone date strings formatted in ISO-8601 (yyyy-mm-dd) or dd/mm/yyyy.
  static DateTime _parseMilestoneDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return DateTime.now();
    }
    final trimmed = dateStr.trim();
    final isoParsed = DateTime.tryParse(trimmed);
    if (isoParsed != null) return isoParsed;

    final delimiter = trimmed.contains('/') ? '/' : (trimmed.contains('-') ? '-' : null);
    if (delimiter != null) {
      final parts = trimmed.split(delimiter);
      if (parts.length == 3) {
        if (parts[2].length == 4) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    }
    return DateTime.now();
  }
}
