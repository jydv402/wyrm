import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Display feature's web remote surface: brightness REST routes, the
/// `set_display` WebSocket command, and the `display` snapshot slice.
class DisplayServerSection implements ServerSection {
  final DisplayState Function() getDisplay;
  final void Function(double brightness) onSetBrightness;

  DisplayServerSection({
    required this.getDisplay,
    required this.onSetBrightness,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.get('/api/display', (Request request) {
      return jsonResponse(getDisplay().toWireJson());
    });
    router.post('/api/display', (Request request) async {
      try {
        final data = await readJsonBody(request);
        final brightness = _executeSetDisplay(data['brightness']);
        if (brightness != null) {
          return jsonOk({'brightness': brightness});
        }
      } catch (_) {}
      return jsonError('Invalid display payload');
    });
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    if ((data['type'] as String?) != 'set_display') return false;
    _executeSetDisplay(data['brightness']);
    return true;
  }

  @override
  Map<String, dynamic>? snapshot() {
    return {'display': getDisplay().toWireJson()};
  }

  /// Parses brightness value and invokes the brightness callback.
  /// Returns the parsed double or null.
  double? _executeSetDisplay(dynamic brightnessRaw) {
    if (brightnessRaw == null) return null;
    final brightness = brightnessRaw is num
        ? brightnessRaw.toDouble()
        : double.tryParse(brightnessRaw.toString());
    if (brightness != null) {
      onSetBrightness(brightness);
    }
    return brightness;
  }
}
