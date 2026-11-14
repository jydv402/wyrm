import 'package:flutter/foundation.dart';
import 'package:qr/qr.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Network feature's web remote surface: the connection-modal toggle route,
/// QR code SVG generation, the `toggle_network_modal` WebSocket command, and
/// the `networkModalOpen` snapshot slice.
class NetworkServerSection implements ServerSection {
  final bool Function() getNetworkModalOpen;
  final void Function(bool open) onToggleNetworkModal;

  NetworkServerSection({
    required this.getNetworkModalOpen,
    required this.onToggleNetworkModal,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.post('/api/modal/network', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeToggleNetworkModal(data['open'] as bool?)) {
          return jsonOk({'open': getNetworkModalOpen()});
        }
      } catch (_) {
        // Empty or unparseable body means "toggle".
        _executeToggleNetworkModal();
        return jsonOk({'open': getNetworkModalOpen()});
      }
      return jsonError('Invalid modal payload');
    });
    router.get(
      '/api/qr',
      (Request request) => _handleGetQrSvg(request, runtime),
    );
    router.get(
      '/api/qr.svg',
      (Request request) => _handleGetQrSvg(request, runtime),
    );
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    if ((data['type'] as String?) != 'toggle_network_modal') return false;
    _executeToggleNetworkModal(data['open'] as bool?);
    return true;
  }

  @override
  Map<String, dynamic>? snapshot() {
    return {'networkModalOpen': getNetworkModalOpen()};
  }

  /// Opens, closes, or toggles the NetworkConnectionModal on the tablet screen.
  bool _executeToggleNetworkModal([bool? open]) {
    final next = open ?? !getNetworkModalOpen();
    onToggleNetworkModal(next);
    return true;
  }

  /// Generates a crisp vector SVG QR code representation of the server URL or custom data payload.
  Future<Response> _handleGetQrSvg(
    Request request,
    ServerRuntime runtime,
  ) async {
    try {
      final requestedData = request.url.queryParameters['data'];
      final ip = await NetworkInfo.getLocalIpAddress();
      final currentPort =
          runtime.port ??
          (kDebugMode
              ? ShelfWebServerDefaults.debugPort
              : ShelfWebServerDefaults.releasePort);
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
      buffer.write(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $count $count" shape-rendering="crispEdges">',
      );
      buffer.write('<rect width="$count" height="$count" fill="#ffffff"/>');
      for (int r = 0; r < count; r++) {
        for (int c = 0; c < count; c++) {
          if (qrImage.isDark(r, c)) {
            buffer.write(
              '<rect x="$c" y="$r" width="1" height="1" fill="#020305"/>',
            );
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
      return Response.internalServerError(
        body: 'Failed to generate QR code: $e',
      );
    }
  }
}

/// Shared server port constants, importable by sections without importing the
/// transport implementation.
abstract final class ShelfWebServerDefaults {
  /// Release default TCP port.
  static const int releasePort = 8080;

  /// Debug default TCP port.
  static const int debugPort = 8081;
}
