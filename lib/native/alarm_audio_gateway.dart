import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform boundary for native alarm chime playback and wake-screen window flags.
///
/// The Android host (`MainActivity.kt`) implements these operations on the
/// `wyrm_desk/alarm` method channel using the system alarm audio stream so
/// reminders remain audible even when media volume is muted.
abstract interface class AlarmAudioGateway {
  /// Starts looping the alarm chime and gentle vibration pulse.
  Future<void> startChime();

  /// Stops active alarm chime playback and vibration, clearing keep-screen-on.
  Future<void> stopChime();

  /// Enables or clears lock-screen visibility and wake-screen flags.
  Future<void> setWakeScreen(bool enabled);
}

/// Live [AlarmAudioGateway] backed by the `wyrm_desk/alarm` [MethodChannel].
///
/// Desktop, web, and unit-test targets without a native handler catch
/// [MissingPluginException] and unsupported platform errors gracefully.
final class MethodChannelAlarmAudioGateway implements AlarmAudioGateway {
  const MethodChannelAlarmAudioGateway();

  /// Method channel implemented by the Android host activity (`MainActivity.kt`).
  static const MethodChannel channel = MethodChannel('wyrm_desk/alarm');

  @override
  Future<void> startChime() => _invoke<bool>('startAlarmChime');

  @override
  Future<void> stopChime() => _invoke<void>('stopAlarmChime');

  @override
  Future<void> setWakeScreen(bool enabled) =>
      _invoke<void>('setWakeScreen', enabled);

  Future<void> _invoke<T>(String method, [Object? arguments]) async {
    try {
      await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint(
          '[AlarmAudioGateway] no native handler for "${channel.name}" '
          '($method) - expected on desktop/test targets.',
        );
      }
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AlarmAudioGateway] platform error calling "$method": '
          '${error.message ?? error.code}',
        );
      }
    } on UnsupportedError catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[AlarmAudioGateway] unsupported target calling "$method": $error',
        );
      }
    }
  }
}

/// In-memory [AlarmAudioGateway] test double recording playback and wake state.
final class FakeAlarmAudioGateway implements AlarmAudioGateway {
  FakeAlarmAudioGateway();

  bool isPlaying = false;
  bool wakeScreenEnabled = false;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> startChime() async {
    isPlaying = true;
    startCount++;
  }

  @override
  Future<void> stopChime() async {
    isPlaying = false;
    stopCount++;
  }

  @override
  Future<void> setWakeScreen(bool enabled) async {
    wakeScreenEnabled = enabled;
  }
}

/// Provider exposing the active [AlarmAudioGateway].
final alarmAudioGatewayProvider = Provider<AlarmAudioGateway>(
  (ref) => const MethodChannelAlarmAudioGateway(),
);
