import 'package:shelf_router/shelf_router.dart';

/// Runtime information a feature's server section can query at request time.
abstract interface class ServerRuntime {
  /// Active TCP port the transport is listening on, or null if stopped.
  int? get port;

  /// LAN IP address the tablet is reachable on.
  String get ipAddress;
}

/// A feature's slice of the web remote server.
///
/// Each feature colocates its REST routes, WebSocket message handling, and its
/// contribution to the shared state snapshot here, so a feature folder reads
/// end-to-end (UI, logic, server surface) without the transport core knowing
/// any feature by name.
abstract interface class ServerSection {
  /// Registers this feature's REST routes on the shared router.
  void registerRoutes(Router router, ServerRuntime runtime);

  /// Handles one WebSocket client message; returns true when consumed.
  bool handleMessage(Map<String, dynamic> message, ServerRuntime runtime);

  /// This feature's slice of `/api/status` and the WebSocket snapshot,
  /// or null when the feature contributes nothing right now.
  Map<String, dynamic>? snapshot();
}
