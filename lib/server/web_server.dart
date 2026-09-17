import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';

/// Embedded Shelf HTTP and WebSocket server hosting the remote web companion.
class ShelfWebServer {
  /// Default TCP port for local tablet remote hosting.
  static const int defaultPort = 8080;

  final CardLayoutConfig Function() getLayoutConfig;
  final AppSettingsConfig Function() getSettingsConfig;
  final void Function(DashboardCardType type, CardSize size) onSetCardSize;
  final void Function(bool is24Hour) onSet24HourFormat;

  /// Optional asset content overrides for headless testing environments.
  final String? htmlOverride;
  final String? cssOverride;
  final String? jsOverride;

  HttpServer? _server;
  final Set<WebSocketChannel> _activeClients = <WebSocketChannel>{};

  ShelfWebServer({
    required this.getLayoutConfig,
    required this.getSettingsConfig,
    required this.onSetCardSize,
    required this.onSet24HourFormat,
    this.htmlOverride,
    this.cssOverride,
    this.jsOverride,
  });

  /// Starts the embedded HTTP and WebSocket server on the designated port.
  Future<HttpServer> start({int port = defaultPort}) async {
    final router = Router();

    // Serve web remote client application assets.
    router.get('/', _handleIndexHtml);
    router.get('/index.html', _handleIndexHtml);
    router.get('/style.css', _handleStyleCss);
    router.get('/app.js', _handleAppJs);

    // REST API endpoints.
    router.get('/api/status', _handleGetStatus);
    router.post('/api/layout', _handlePostLayout);
    router.post('/api/settings', _handlePostSettings);

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

  /// Broadcasts updated layout and settings state to all connected WebSocket clients.
  void broadcastState({
    CardLayoutConfig? layout,
    AppSettingsConfig? settings,
  }) {
    final activeLayout = layout ?? getLayoutConfig();
    final activeSettings = settings ?? getSettingsConfig();

    final payload = jsonEncode({
      'type': 'state_update',
      'layout': activeLayout.toJson(),
      'settings': {
        'is24HourFormat': activeSettings.is24HourFormat,
      },
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

    // Send immediate state snapshot upon connection.
    final initialSnapshot = jsonEncode({
      'type': 'snapshot',
      'layout': getLayoutConfig().toJson(),
      'settings': {
        'is24HourFormat': getSettingsConfig().is24HourFormat,
      },
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
          'Cache-Control': 'no-cache',
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
          'Cache-Control': 'no-cache',
        },
      );
    } catch (_) {
      return Response.notFound('// JS asset not found');
    }
  }

  /// Returns current system status, card layout, and clock settings in JSON.
  Response _handleGetStatus(Request request) {
    final layout = getLayoutConfig();
    final settings = getSettingsConfig();

    return Response.ok(
      jsonEncode({
        'status': 'online',
        'layout': layout.toJson(),
        'settings': {
          'is24HourFormat': settings.is24HourFormat,
        },
      }),
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

  /// Mutates clock settings via REST POST call.
  Future<Response> _handlePostSettings(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data.containsKey('is24HourFormat')) {
        final is24Hour = data['is24HourFormat'] as bool;
        onSet24HourFormat(is24Hour);
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
    }
  }
}
