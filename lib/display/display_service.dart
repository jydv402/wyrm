import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges brightness requests from Dart to the native host.
///
/// The tablet's panel is driven through a window-level brightness override, which
/// lets the remote dim the display. Platforms that never register a handler (unit
/// tests, desktop builds) ignore every request; failures are logged in debug so a
/// missing native handler (`MissingPluginException`) is never silent.
class DisplayService {
  DisplayService._();

  /// Method channel implemented by the Android host activity (`MainActivity.kt`).
  static const MethodChannel channel = MethodChannel('wyrm_desk/display');

  /// Applies the requested panel brightness to the host window.
  ///
  /// [brightness] is a value between 0.0 and 1.0.
  static Future<void> apply({
    required double brightness,
  }) async {
    try {
      await channel.invokeMethod<void>('setPanelState', <String, dynamic>{
        'brightness': brightness,
      });
      if (kDebugMode) {
        debugPrint('[DisplayService] applied brightness=$brightness');
      }
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint(
          '[DisplayService] no native handler for "$channel" — '
          'panel control needs an Android build (rebuild/reinstall the app).',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DisplayService] failed to apply panel state: $error');
      }
    }
  }
}
