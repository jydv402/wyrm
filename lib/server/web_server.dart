import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:wyrm_desk/calendar/calendar_state.dart';
import 'package:wyrm_desk/display/display_state.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/server/network_info.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';

/// Embedded Shelf HTTP and WebSocket server hosting the remote web companion.
///
/// This server enables users to control their desk tablet remotely from a phone,
/// desktop browser, or local network. It exposes:
/// 1. A static file server for the offline Vue 3 remote client (`assets/web/`).
/// 2. REST API endpoints under `/api/*` for one-off operations and data queries.
/// 3. A real-time WebSocket connection at `/ws` for bi-directional live synchronization.
class ShelfWebServer {
  /// Default TCP port used for hosting the local web remote.
  static const int defaultPort = 8080;

  // ---------------------------------------------------------------------------
  // State provider getters: Called whenever a fresh snapshot is needed.
  // ---------------------------------------------------------------------------
  final CardLayoutConfig Function() getLayoutConfig;
  final AppSettingsConfig Function() getSettingsConfig;
  final List<TaskItem> Function()? getTasksConfig;
  final CalendarState Function()? getCalendarConfig;
  final HabitsState Function()? getHabitsConfig;
  final DisplayState Function()? getDisplayConfig;
  final bool Function()? getNetworkModalConfig;

  // ---------------------------------------------------------------------------
  // Action callbacks: Executed in response to client mutations.
  // ---------------------------------------------------------------------------
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
  final void Function(bool open)? onToggleNetworkModal;

  // ---------------------------------------------------------------------------
  // Testing overrides: In-memory string/byte mocks used by headless unit tests.
  // ---------------------------------------------------------------------------
  final String? htmlOverride;
  final String? cssOverride;
  final String? jsOverride;
  final List<int>? faviconOverride;

  HttpServer? _server;
  String _ipAddress = '127.0.0.1';
  final Set<WebSocketChannel> _activeClients = <WebSocketChannel>{};

  ShelfWebServer({
    required this.getLayoutConfig,
    required this.getSettingsConfig,
    this.getTasksConfig,
    this.getCalendarConfig,
    this.getHabitsConfig,
    this.getDisplayConfig,
    this.getNetworkModalConfig,
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
    this.onToggleNetworkModal,
    this.htmlOverride,
    this.cssOverride,
    this.jsOverride,
    this.faviconOverride,
  });

  // ===========================================================================
  // SECTION 1: SERVER LIFECYCLE & ROUTING
  // ===========================================================================

  /// Starts the embedded HTTP and WebSocket server on the designated TCP port.
  Future<HttpServer> start({int port = defaultPort}) async {
    _ipAddress = await NetworkInfo.getLocalIpAddress();
    final router = Router();

    // --- Static Web Client Assets ---
    router.get('/', _handleIndexHtml);
    router.get('/index.html', _handleIndexHtml);
    router.get('/style.css', _handleStyleCss);
    router.get('/app.js', _handleAppJs);
    router.get('/favicon.ico', _handleFavicon);
    router.get('/icon_flat.png', _handleFavicon);
    router.get('/assets/icons/icon_flat.png', _handleFavicon);
    router.get('/assets/web/<file|.*>', _handleStaticAsset);
    router.get('/<file|.*\\.(?:js|css|png|svg|json|webmanifest|ico|woff2?)>', _handleStaticAsset);

    // --- REST API Endpoints ---
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
    router.post('/api/modal/network', _handlePostToggleNetworkModal);
    router.get('/api/qr', _handleGetQrSvg);
    router.get('/api/qr.svg', _handleGetQrSvg);

    // --- WebSocket Real-Time Channel ---
    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel webSocket, [String? protocol]) {
        _handleWebSocketConnection(webSocket);
      }),
    );

    // Wrap the router with Shelf middleware (request logging) and bind the socket.
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

  /// Gracefully closes all active WebSocket clients and terminates the HTTP server.
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

  /// Active TCP port the server is listening on, or null if stopped.
  int? get port => _server?.port;

  /// Number of active WebSocket clients connected to the server.
  int get connectedClientsCount => _activeClients.length;

  // ===========================================================================
  // SECTION 2: STATE AGGREGATION & BROADCASTING
  // ===========================================================================

  /// Assembles a complete snapshot dictionary representing the tablet's live state.
  ///
  /// This single method serves as the single source of truth for:
  /// - Initial WebSocket handshake snapshots (`type: 'snapshot'`)
  /// - Real-time state push notifications (`type: 'state_update'`)
  /// - REST status queries (`GET /api/status`)
  Map<String, dynamic> _buildStateSnapshot({
    CardLayoutConfig? layout,
    AppSettingsConfig? settings,
    List<TaskItem>? tasks,
    CalendarState? calendar,
    HabitsState? habits,
    DisplayState? display,
    bool? networkModalOpen,
    String? type,
  }) {
    final activeLayout = layout ?? getLayoutConfig();
    final activeSettings = settings ?? getSettingsConfig();
    final activeTasks = tasks ?? (getTasksConfig != null ? getTasksConfig!() : <TaskItem>[]);
    final activeCalendar = calendar ?? (getCalendarConfig != null ? getCalendarConfig!() : null);
    final activeHabits = habits ?? (getHabitsConfig != null ? getHabitsConfig!() : const HabitsState());
    final activeDisplay = display ?? (getDisplayConfig != null ? getDisplayConfig!() : const DisplayState());
    final activeModalOpen = networkModalOpen ?? (getNetworkModalConfig != null ? getNetworkModalConfig!() : false);

    return {
      'type': ?type,
      'layout': activeLayout.toJson(),
      'settings': {
        'is24HourFormat': activeSettings.is24HourFormat,
        'cardFontSize': activeSettings.cardFontSize,
        'startWeekOnMonday': activeSettings.startWeekOnMonday,
      },
      'display': activeDisplay.toWireJson(),
      'networkModalOpen': activeModalOpen,
      'serverUrl': 'http://$_ipAddress:${port ?? defaultPort}',
      'ipAddress': _ipAddress,
      'tasks': activeTasks.map((t) => t.toJson()).toList(),
      'calendar': _serializeCalendarState(activeCalendar, activeSettings.startWeekOnMonday),
      'habits': activeHabits.habits.map((h) => h.toJson()).toList(),
    };
  }

  /// Broadcasts updated state to all connected WebSocket clients in real-time.
  void broadcastState({
    CardLayoutConfig? layout,
    AppSettingsConfig? settings,
    List<TaskItem>? tasks,
    CalendarState? calendar,
    HabitsState? habits,
    DisplayState? display,
    bool? networkModalOpen,
  }) {
    final payload = jsonEncode(_buildStateSnapshot(
      layout: layout,
      settings: settings,
      tasks: tasks,
      calendar: calendar,
      habits: habits,
      display: display,
      networkModalOpen: networkModalOpen,
      type: 'state_update',
    ));

    for (final client in _activeClients.toList()) {
      try {
        client.sink.add(payload);
      } catch (_) {
        _activeClients.remove(client);
      }
    }
  }

  /// Serializes calendar state into JSON, computing progress metrics if null.
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

  // ===========================================================================
  // SECTION 3: WEBSOCKET REAL-TIME CHANNEL
  // ===========================================================================

  /// Manages an incoming WebSocket client connection, dispatching commands to executors.
  void _handleWebSocketConnection(WebSocketChannel webSocket) {
    _activeClients.add(webSocket);

    // 1. Send immediate snapshot so the client UI hydrates synchronously.
    final initialSnapshot = jsonEncode(_buildStateSnapshot(type: 'snapshot'));
    try {
      webSocket.sink.add(initialSnapshot);
    } catch (_) {}

    // 2. Listen for incoming client action messages.
    webSocket.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString()) as Map<String, dynamic>;
          final type = data['type'] as String?;

          switch (type) {
            case 'set_layout':
              _executeSetLayout(data['card'] as String?, data['size'] as String?);
              break;
            case 'set_settings':
              _executeSetSettings(data);
              break;
            case 'set_display':
              _executeSetDisplay(data['brightness']);
              break;
            case 'create_task':
              _executeCreateTask(data['title'] as String?, data['priority'] as String?);
              break;
            case 'toggle_task':
              _executeToggleTask(data['id']);
              break;
            case 'delete_task':
              _executeDeleteTask(data['id']);
              break;
            case 'create_milestone':
              _executeCreateMilestone(
                data['title'] as String?,
                (data['target_date'] ?? data['targetDate'] ?? data['date']) as String?,
                (data['is_pinned'] ?? data['isPinned'] ?? false) as bool,
              );
              break;
            case 'delete_milestone':
              _executeDeleteMilestone(data['id']);
              break;
            case 'toggle_pin_milestone':
              _executeTogglePinMilestone(data['id']);
              break;
            case 'create_habit':
              _executeCreateHabit(data);
              break;
            case 'toggle_habit':
              _executeToggleHabit(data['id'], data['date'] as String?);
              break;
            case 'step_habit':
              _executeStepHabit(data['id'], data['delta'], data['date'] as String?);
              break;
            case 'delete_habit':
              _executeDeleteHabit(data['id']);
              break;
            case 'scroll_to_card':
              _executeScroll(data['card'] as String?);
              break;
            case 'toggle_network_modal':
              _executeToggleNetworkModal(data['open'] as bool?);
              break;
            case 'ping':
              final timestamp = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
              webSocket.sink.add(jsonEncode({'type': 'pong', 'timestamp': timestamp}));
              break;
          }
        } catch (_) {}
      },
      onDone: () => _activeClients.remove(webSocket),
      onError: (_) => _activeClients.remove(webSocket),
      cancelOnError: true,
    );
  }

  // ===========================================================================
  // SECTION 4: SHARED ACTION EXECUTORS
  // ===========================================================================
  // These methods encapsulate parameter validation and business logic execution.
  // Both WebSocket and REST route handlers delegate directly to them to guarantee
  // uniform behavior and eliminate code duplication.

  /// Applies card size and triggers auto-scroll to the adjusted card.
  bool _executeSetLayout(String? cardName, String? sizeName) {
    if (cardName == null || sizeName == null) return false;

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
      return true;
    }
    return false;
  }

  /// Parses and applies general application settings (clock format, font size, week start).
  bool _executeSetSettings(Map<String, dynamic> data) {
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
    return updated;
  }

  /// Parses brightness value and invokes the brightness callback. Returns parsed double or null.
  double? _executeSetDisplay(dynamic brightnessRaw) {
    if (brightnessRaw == null) return null;
    final brightness = brightnessRaw is num
        ? brightnessRaw.toDouble()
        : double.tryParse(brightnessRaw.toString());

    if (brightness != null && onSetBrightness != null) {
      onSetBrightness!(brightness);
      return brightness;
    }
    return null;
  }

  /// Validates and triggers task creation.
  bool _executeCreateTask(String? title, String? priority) {
    if (title != null && title.trim().isNotEmpty && onAddTask != null) {
      onAddTask!(title.trim(), (priority ?? 'normal').trim());
      return true;
    }
    return false;
  }

  /// Toggles completion status for an existing task.
  bool _executeToggleTask(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null && onToggleTask != null) {
      onToggleTask!(id);
      return true;
    }
    return false;
  }

  /// Deletes a task by ID.
  bool _executeDeleteTask(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null && onDeleteTask != null) {
      onDeleteTask!(id);
      return true;
    }
    return false;
  }

  /// Creates a calendar milestone with flexible date string parsing.
  bool _executeCreateMilestone(String? title, String? dateStr, bool isPinned) {
    if (title != null && title.trim().isNotEmpty && onAddMilestone != null) {
      final targetDate = _parseMilestoneDate(dateStr);
      onAddMilestone!(title.trim(), targetDate, isPinned: isPinned);
      return true;
    }
    return false;
  }

  /// Deletes a milestone by ID.
  bool _executeDeleteMilestone(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null && onDeleteMilestone != null) {
      onDeleteMilestone!(id);
      return true;
    }
    return false;
  }

  /// Toggles pinned status for a milestone by ID.
  bool _executeTogglePinMilestone(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null && onTogglePinMilestone != null) {
      onTogglePinMilestone!(id);
      return true;
    }
    return false;
  }

  /// Parses habit parameters (handling field aliases) and triggers creation.
  bool _executeCreateHabit(Map<String, dynamic> data) {
    final title = (data['title'] ?? data['name']) as String?;
    final typeStr = (data['habit_type'] ?? data['type'] ?? 'binary') as String;
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
      return true;
    }
    return false;
  }

  /// Toggles completion status for a habit on a specific date.
  bool _executeToggleHabit(dynamic idRaw, String? dateStr) {
    final id = idRaw?.toString();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (id != null && onToggleHabit != null) {
      onToggleHabit!(id, date);
      return true;
    }
    return false;
  }

  /// Increments or decrements a numeric habit count by delta on a specific date.
  bool _executeStepHabit(dynamic idRaw, dynamic deltaRaw, String? dateStr) {
    final id = idRaw?.toString();
    final delta = deltaRaw is int
        ? deltaRaw
        : (int.tryParse(deltaRaw?.toString() ?? '1') ?? 1);
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (id != null && onStepHabit != null) {
      onStepHabit!(id, delta, date);
      return true;
    }
    return false;
  }

  /// Deletes a habit by ID.
  bool _executeDeleteHabit(dynamic idRaw) {
    final id = idRaw?.toString();
    if (id != null && onDeleteHabit != null) {
      onDeleteHabit!(id);
      return true;
    }
    return false;
  }

  /// Triggers view scrolling to the specified dashboard card.
  DashboardCardType? _executeScroll(String? cardName) {
    final card = DashboardCardType.tryParse(cardName);
    if (card != null && onScrollToCard != null) {
      onScrollToCard!(card);
      return card;
    }
    return null;
  }

  /// Opens, closes, or toggles the NetworkConnectionModal on the tablet screen.
  bool _executeToggleNetworkModal([bool? open]) {
    if (onToggleNetworkModal != null) {
      final current = getNetworkModalConfig != null ? getNetworkModalConfig!() : false;
      final next = open ?? !current;
      onToggleNetworkModal!(next);
      return true;
    }
    return false;
  }

  // ===========================================================================
  // SECTION 5: REST API HANDLERS
  // ===========================================================================

  Response _handleGetStatus(Request request) {
    return _jsonResponse({'status': 'online', ..._buildStateSnapshot()});
  }

  Response _handleGetDisplay(Request request) {
    final display = getDisplayConfig != null ? getDisplayConfig!() : const DisplayState();
    return _jsonResponse(display.toWireJson());
  }

  Future<Response> _handlePostDisplay(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final brightness = _executeSetDisplay(data['brightness']);
      if (brightness != null) {
        return _jsonOk({'brightness': brightness});
      }
    } catch (_) {}
    return _jsonError('Invalid display payload');
  }

  Future<Response> _handlePostLayout(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeSetLayout(data['card'] as String?, data['size'] as String?)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid layout payload');
  }

  Future<Response> _handlePostScroll(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final card = _executeScroll(data['card'] as String?);
      if (card != null) {
        return _jsonOk({'card': card.name});
      }
    } catch (_) {}
    return _jsonError('Invalid scroll payload');
  }

  Future<Response> _handlePostSettings(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeSetSettings(data)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid settings payload');
  }

  Response _handleGetTasks(Request request) {
    final tasks = getTasksConfig != null ? getTasksConfig!() : <TaskItem>[];
    return _jsonResponse(tasks.map((t) => t.toJson()).toList());
  }

  Future<Response> _handlePostTask(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final title = (data['title'] ?? data['text']) as String?;
      final priority = data['priority'] as String?;
      if (_executeCreateTask(title, priority)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid task payload');
  }

  Future<Response> _handlePostToggleTask(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeToggleTask(data['id'])) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid toggle task payload');
  }

  Future<Response> _handlePostDeleteTask(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeDeleteTask(data['id'])) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid delete task payload');
  }

  Response _handleGetCalendar(Request request) {
    final calendar = getCalendarConfig != null ? getCalendarConfig!() : null;
    final settings = getSettingsConfig();
    return _jsonResponse(_serializeCalendarState(calendar, settings.startWeekOnMonday));
  }

  Future<Response> _handlePostAddMilestone(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final title = (data['title'] ?? data['name']) as String?;
      final dateStr = (data['target_date'] ?? data['targetDate'] ?? data['date']) as String?;
      final isPinned = (data['is_pinned'] ?? data['isPinned'] ?? false) as bool;
      if (_executeCreateMilestone(title, dateStr, isPinned)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid milestone payload');
  }

  Future<Response> _handlePostDeleteMilestone(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeDeleteMilestone(data['id'])) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid delete milestone payload');
  }

  Future<Response> _handlePostPinMilestone(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeTogglePinMilestone(data['id'])) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid pin milestone payload');
  }

  Future<Response> _handleGetHabits(Request request) async {
    final habits = getHabitsConfig != null ? getHabitsConfig!().habits : <HabitItem>[];
    return _jsonResponse(habits.map((h) => h.toJson()).toList());
  }

  Future<Response> _handlePostAddHabit(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeCreateHabit(data)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid habit payload');
  }

  Future<Response> _handlePostToggleHabit(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final dateStr = (data['date'] ?? data['target_date']) as String?;
      if (_executeToggleHabit(data['id'], dateStr)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid toggle habit payload');
  }

  Future<Response> _handlePostStepHabit(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final dateStr = (data['date'] ?? data['target_date']) as String?;
      if (_executeStepHabit(data['id'], data['delta'], dateStr)) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid step habit payload');
  }

  Future<Response> _handlePostDeleteHabit(Request request) async {
    try {
      final data = await _readJsonBody(request);
      if (_executeDeleteHabit(data['id'])) {
        return _jsonOk();
      }
    } catch (_) {}
    return _jsonError('Invalid delete habit payload');
  }

  Future<Response> _handlePostToggleNetworkModal(Request request) async {
    try {
      final data = await _readJsonBody(request);
      final open = data['open'] as bool?;
      if (_executeToggleNetworkModal(open)) {
        final current = getNetworkModalConfig != null ? getNetworkModalConfig!() : (open ?? true);
        return _jsonOk({'open': current});
      }
    } catch (_) {
      if (_executeToggleNetworkModal(null)) {
        final current = getNetworkModalConfig != null ? getNetworkModalConfig!() : true;
        return _jsonOk({'open': current});
      }
    }
    return _jsonError('Invalid modal payload');
  }

  /// Generates a crisp vector SVG QR code representation of the server URL or custom data payload.
  Future<Response> _handleGetQrSvg(Request request) async {
    try {
      final requestedData = request.url.queryParameters['data'];
      final ip = await NetworkInfo.getLocalIpAddress();
      final currentPort = port ?? defaultPort;
      final data = (requestedData != null && requestedData.isNotEmpty)
          ? requestedData
          : 'http://$ip:$currentPort';

      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final count = qrImage.moduleCount;
      final buffer = StringBuffer();
      buffer.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $count $count" shape-rendering="crispEdges">');
      buffer.write('<rect width="$count" height="$count" fill="#ffffff"/>');
      for (int r = 0; r < count; r++) {
        for (int c = 0; c < count; c++) {
          if (qrImage.isDark(r, c)) {
            buffer.write('<rect x="$c" y="$r" width="1" height="1" fill="#020305"/>');
          }
        }
      }
      buffer.write('</svg>');
      return Response.ok(
        buffer.toString(),
        headers: {
          'Content-Type': 'image/svg+xml; charset=utf-8',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'Failed to generate QR code: $e');
    }
  }

  // ===========================================================================
  // SECTION 6: STATIC ASSET SERVING
  // ===========================================================================

  /// Resolves asset binary data from local disk first (for live updates during development),
  /// falling back to Flutter's compiled [rootBundle] in release or production APK builds.
  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    final file = File(assetPath);
    if (await file.exists()) {
      return file.readAsBytes();
    }
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// Serves the root HTML client document.
  Future<Response> _handleIndexHtml(Request request) async {
    if (htmlOverride != null) {
      return Response.ok(htmlOverride!, headers: _assetHeaders('text/html; charset=utf-8', isDynamic: true));
    }
    final bytes = await _loadAssetBytes('assets/web/index.html');
    if (bytes != null) {
      return Response.ok(bytes, headers: _assetHeaders('text/html; charset=utf-8', isDynamic: true));
    }
    return Response.ok(
      '<!DOCTYPE html><html><body><h1>WYRM Desk Server Running</h1></body></html>',
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  /// Serves the modular CSS stylesheet.
  Future<Response> _handleStyleCss(Request request) async {
    if (cssOverride != null) {
      return Response.ok(cssOverride!, headers: _assetHeaders('text/css; charset=utf-8', isDynamic: true));
    }
    final bytes = await _loadAssetBytes('assets/web/style.css');
    if (bytes != null) {
      return Response.ok(bytes, headers: _assetHeaders('text/css; charset=utf-8', isDynamic: true));
    }
    return Response.notFound('/* CSS asset not found */');
  }

  /// Serves the client JavaScript logic.
  Future<Response> _handleAppJs(Request request) async {
    if (jsOverride != null) {
      return Response.ok(jsOverride!, headers: _assetHeaders('application/javascript; charset=utf-8', isDynamic: true));
    }
    final bytes = await _loadAssetBytes('assets/web/app.js');
    if (bytes != null) {
      return Response.ok(bytes, headers: _assetHeaders('application/javascript; charset=utf-8', isDynamic: true));
    }
    return Response.notFound('// JS asset not found');
  }

  /// Serves the web favicon icon.
  Future<Response> _handleFavicon(Request request) async {
    if (faviconOverride != null) {
      return Response.ok(faviconOverride!, headers: _assetHeaders('image/png', isDynamic: false));
    }
    final bytes = await _loadAssetBytes('assets/icons/icon_flat.png') ??
        await _loadAssetBytes('assets/web/icon_flat.png');
    if (bytes != null) {
      return Response.ok(bytes, headers: _assetHeaders('image/png', isDynamic: false));
    }
    return Response.notFound('Favicon asset not found');
  }

  /// Serves static assets located inside `assets/web/` dynamically.
  Future<Response> _handleStaticAsset(Request request) async {
    String filePath = request.url.path;
    if (filePath.startsWith('assets/web/')) {
      filePath = filePath.substring('assets/web/'.length);
    }
    final assetPath = 'assets/web/$filePath';
    final bytes = await _loadAssetBytes(assetPath);
    if (bytes != null) {
      final mime = _getMimeType(filePath);
      final isDynamic = filePath.endsWith('.js') ||
          filePath.endsWith('.css') ||
          filePath.endsWith('.html') ||
          filePath.endsWith('.webmanifest');
      return Response.ok(bytes, headers: _assetHeaders(mime, isDynamic: isDynamic));
    }
    return Response.notFound('Asset not found: $filePath');
  }

  // ===========================================================================
  // SECTION 7: HTTP & JSON HELPERS
  // ===========================================================================

  /// Reads and parses an incoming JSON request body.
  static Future<Map<String, dynamic>> _readJsonBody(Request request) async {
    final body = await request.readAsString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Formats a standardized JSON response with no-cache headers.
  static Response _jsonResponse(dynamic data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
      },
    );
  }

  /// Returns a standardized JSON success response: `{"success": true, ...}`.
  static Response _jsonOk([Map<String, dynamic>? extra]) {
    return _jsonResponse({'success': true, ...?extra});
  }

  /// Returns a standardized JSON error response: `{"error": "message"}`.
  static Response _jsonError(String message, {int statusCode = 400}) {
    return _jsonResponse({'error': message}, statusCode: statusCode);
  }

  /// Formats standard asset headers with cache directives (strict no-cache for scripts/styles).
  static Map<String, String> _assetHeaders(String contentType, {required bool isDynamic}) {
    return {
      'Content-Type': contentType,
      'Cache-Control': isDynamic ? 'no-cache, no-store, must-revalidate' : 'public, max-age=86400',
      if (isDynamic) 'Pragma': 'no-cache',
      if (isDynamic) 'Expires': '0',
    };
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
      if (parts.length == 3 && parts[2].length == 4) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return DateTime.now();
  }
}
