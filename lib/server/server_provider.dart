import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/settings/settings_state.dart';

/// Provider managing the background Shelf HTTP and WebSocket server lifecycle.
final webServerProvider = Provider<ShelfWebServer>((ref) {
  final server = ShelfWebServer(
    getLayoutConfig: () => ref.read(cardLayoutProvider),
    getSettingsConfig: () => ref.read(appSettingsProvider),
    onSetCardSize: (type, size) {
      ref.read(cardLayoutProvider.notifier).setCardSize(type, size);
    },
    onSet24HourFormat: (is24Hour) {
      ref.read(appSettingsProvider.notifier).set24HourFormat(is24Hour);
    },
  );

  // Auto-start the server on application startup.
  server.start().catchError((error) {
    // Gracefully handle port conflicts or permission constraints.
    return Future<HttpServer>.error(error);
  });

  // Synchronize layout changes originating on the tablet to connected web clients.
  ref.listen<CardLayoutConfig>(cardLayoutProvider, (previous, next) {
    server.broadcastState(layout: next);
  });

  // Synchronize settings changes originating on the tablet to connected web clients.
  ref.listen<AppSettingsConfig>(appSettingsProvider, (previous, next) {
    server.broadcastState(settings: next);
  });

  ref.onDispose(() {
    server.stop();
  });

  return server;
});
