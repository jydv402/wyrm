import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_server_section.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Embedded Shelf HTTP and WebSocket transport hosting the remote web companion.
///
/// This server is feature-agnostic: it owns the lifecycle, static asset
/// serving, the `/ws` channel, the shared snapshot envelope, and the backup
/// endpoints. Every feature-specific route and WebSocket command lives in a
/// [ServerSection] colocated with its feature (see the `*_server_section.dart`
/// files under `lib/features/` and `lib/config/`).
class ShelfWebServer implements ServerRuntime {
  /// Release default TCP port.
  static const int releasePort = ShelfWebServerDefaults.releasePort;

  /// Debug default TCP port.
  static const int debugPort = ShelfWebServerDefaults.debugPort;

  /// Default TCP port used for hosting the local web remote (8081 for debug, 8080 for release).
  static int get defaultPort => kDebugMode ? debugPort : releasePort;

  /// Feature-owned sections providing routes, WebSocket commands, and snapshot slices.
  final List<ServerSection> sections;

  /// Imports a full database JSON backup payload. Defaults to the shared
  /// AppDatabase importer when not overridden.
  final Future<bool> Function(String jsonString)? onImportDatabase;

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
    required this.sections,
    this.onImportDatabase,
    this.htmlOverride,
    this.cssOverride,
    this.jsOverride,
    this.faviconOverride,
  });

  @override
  int? get port => _server?.port;

  @override
  String get ipAddress => _ipAddress;

  /// Starts the embedded HTTP and WebSocket server on the designated TCP port.
  Future<HttpServer> start({int? port}) async {
    final effectivePort = port ?? defaultPort;
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

    // --- Feature-owned REST routes ---
    for (final section in sections) {
      section.registerRoutes(router, this);
    }

    // --- Shared status endpoint (envelope + every section's slice) ---
    router.get('/api/status', (Request request) => jsonResponse(_buildStateSnapshot()));

    // --- Backup endpoints (whole-database concern, kept in the transport) ---
    router.get('/api/backup/export', _handleGetBackupExport);
    router.get('/api/backup', _handleGetBackupExport);
    router.post('/api/backup/import', _handlePostBackupImport);

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
      effectivePort,
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

  /// Number of active WebSocket clients connected to the server.
  int get connectedClientsCount => _activeClients.length;

  // ===========================================================================
  // STATE AGGREGATION & BROADCASTING
  // ===========================================================================

  /// Assembles the complete snapshot dictionary representing the tablet's
  /// live state: the transport envelope plus every section's snapshot slice.
  ///
  /// This single method serves as the single source of truth for:
  /// - Initial WebSocket handshake snapshots (`type: 'snapshot'`)
  /// - Real-time state push notifications (`type: 'state_update'`)
  /// - REST status queries (`GET /api/status`)
  Map<String, dynamic> _buildStateSnapshot({String? type}) {
    return {
      'type': ?type,
      'status': 'online',
      'serverUrl': 'http://$_ipAddress:${port ?? defaultPort}',
      'ipAddress': _ipAddress,
      for (final section in sections)
        ...?section.snapshot(),
    };
  }

  /// Broadcasts the full current state to all connected WebSocket clients.
  void broadcastState() {
    final payload = jsonEncode(_buildStateSnapshot(type: 'state_update'));

    for (final client in _activeClients.toList()) {
      try {
        client.sink.add(payload);
      } catch (_) {
        _activeClients.remove(client);
      }
    }
  }

  // ===========================================================================
  // WEBSOCKET REAL-TIME CHANNEL
  // ===========================================================================

  /// Manages an incoming WebSocket client connection, dispatching commands to
  /// the feature sections.
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

          if (data['type'] == 'ping') {
            final timestamp =
                data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
            webSocket.sink.add(jsonEncode({'type': 'pong', 'timestamp': timestamp}));
            return;
          }

          for (final section in sections) {
            if (section.handleMessage(data, this)) break;
          }
        } catch (_) {}
      },
      onDone: () => _activeClients.remove(webSocket),
      onError: (_) => _activeClients.remove(webSocket),
      cancelOnError: true,
    );
  }

  // ===========================================================================
  // BACKUP ENDPOINTS
  // ===========================================================================

  /// Exports the entire database document as a downloadable JSON file attachment.
  Future<Response> _handleGetBackupExport(Request request) async {
    try {
      final jsonString = await AppDatabase.exportDatabaseJson();
      return Response.ok(
        jsonString,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Content-Disposition': 'attachment; filename="${AppDatabase.backupFileName}"',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to export database backup: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Imports and validates a full database JSON backup payload.
  Future<Response> _handlePostBackupImport(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.trim().isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Backup payload cannot be empty'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final success = onImportDatabase != null
          ? await onImportDatabase!(body)
          : await AppDatabase.importDatabaseJson(body);

      if (!success) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid or corrupted database backup JSON'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Broadcast fresh state update to all connected WebSocket clients.
      broadcastState();

      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'message': 'Database backup imported successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to import database backup: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ===========================================================================
  // STATIC ASSET SERVING
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
}
