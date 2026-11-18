import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';

/// Live wall-clock time, ticking once a second.
///
/// Emits immediately so the faces never wait a second for their first value.
final clockTimeProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// Latest tick, or the wall clock before the first tick lands.
DateTime _time(Ref ref) => ref.watch(clockTimeProvider).value ?? DateTime.now();

String _pad(int value) => value.toString().padLeft(2, '0');

/// Hour digits, padded and honouring the 12/24-hour setting.
final clockHoursProvider = Provider.autoDispose<String>((ref) {
  final hour = _time(ref).hour;
  if (ref.watch(appSettingsProvider).is24HourFormat) return _pad(hour);
  final twelve = hour % 12;
  return _pad(twelve == 0 ? 12 : twelve);
});

/// Minute digits, padded.
final clockMinutesProvider = Provider.autoDispose<String>(
  (ref) => _pad(_time(ref).minute),
);

/// Second digits, padded. The only value that changes every tick.
final clockSecondsProvider = Provider.autoDispose<String>(
  (ref) => _pad(_time(ref).second),
);

/// AM/PM badge, or null in 24-hour mode.
final clockPeriodProvider = Provider.autoDispose<String?>((ref) {
  if (ref.watch(appSettingsProvider).is24HourFormat) return null;
  return _time(ref).hour < 12 ? 'AM' : 'PM';
});

/// Short date above the time, e.g. `Thu, Sep 17`.
///
/// This provider still runs on every tick, so the pattern is compiled once
/// rather than rebuilt a second at a time.
final _dateFormat = DateFormat('EEE, MMM d');

final clockDateProvider = Provider.autoDispose<String>(
  (ref) => _dateFormat.format(_time(ref)),
);

/// Hours and minutes left in the civil day, for the countdown pill.
final timeLeftTodayPartsProvider =
    Provider.autoDispose<({int hours, int minutes})>((ref) {
      final now = _time(ref);
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final left = midnight.difference(now);
      return (hours: left.inHours, minutes: left.inMinutes % 60);
    });

/// Hand positions in radians for the analogue dial.
///
/// Seconds step a whole second at a time rather than sweeping, because the dial
/// is drawn as a discrete instrument rather than a smooth mechanism.
typedef ClockHandAngles = ({double hour, double minute, double second});

/// Angles for the three hands at the current tick.
final clockHandAnglesProvider = Provider.autoDispose<ClockHandAngles>((ref) {
  final time = _time(ref);
  const tau = 2 * math.pi;
  return (
    hour: (((time.hour % 12) + time.minute / 60) / 12) * tau,
    minute: ((time.minute + time.second / 60) / 60) * tau,
    second: (time.second / 60) * tau,
  );
});

/// The photograph matching the current hour.
///
/// - 04–07 fog · 07–11 morning · 11–16 noon ·
/// - 16–19 golden hour · 19–04 night
final clockBackgroundAssetProvider = Provider.autoDispose<String>((ref) {
  final hour = _time(ref).hour;
  if (hour >= 4 && hour < 7) return 'assets/card_bg/clock/clock_1.png';
  if (hour >= 7 && hour < 11) return 'assets/card_bg/clock/clock_2.png';
  if (hour >= 11 && hour < 16) return 'assets/card_bg/clock/clock_3.png';
  if (hour >= 16 && hour < 19) return 'assets/card_bg/clock/clock_4.png';
  return 'assets/card_bg/clock/clock_5.png';
});
