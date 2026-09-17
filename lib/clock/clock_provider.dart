import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/settings/settings.dart';

/// Periodic stream emitting the current DateTime once every second.
final clockTimeProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();

  // Emit immediate current time on subscription.
  controller.add(DateTime.now());

  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!controller.isClosed) {
      controller.add(DateTime.now());
    }
  });

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Granular provider emitting formatted hour digits, rebuilding only when the hour changes.
final clockHoursProvider = Provider.autoDispose<String>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  final is24Hour = ref.watch(appSettingsProvider).is24HourFormat;

  if (is24Hour) {
    return time.hour.toString().padLeft(2, '0');
  } else {
    final h = time.hour % 12;
    final displayHour = h == 0 ? 12 : h;
    return displayHour.toString().padLeft(2, '0');
  }
});

/// Granular provider emitting formatted minute digits, rebuilding only when the minute changes.
final clockMinutesProvider = Provider.autoDispose<String>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  return time.minute.toString().padLeft(2, '0');
});

/// Granular provider emitting formatted seconds, rebuilding every second.
final clockSecondsProvider = Provider.autoDispose<String>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  return time.second.toString().padLeft(2, '0');
});

/// Granular provider emitting the AM/PM period badge, or null if 24-hour mode is active.
final clockPeriodProvider = Provider.autoDispose<String?>((ref) {
  final is24Hour = ref.watch(appSettingsProvider).is24HourFormat;
  if (is24Hour) return null;

  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  return time.hour >= 12 ? 'PM' : 'AM';
});

/// Granular provider calculating remaining time until midnight, updating only once per minute.
final timeLeftTodayProvider = Provider.autoDispose<String>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  final endOfDay = DateTime(time.year, time.month, time.day + 1);
  final difference = endOfDay.difference(time);

  final hoursLeft = difference.inHours;
  final minutesLeft = difference.inMinutes % 60;

  return '${hoursLeft}h ${minutesLeft}m left today';
});

/// Discrete stepping angles in radians for analogue clock hands.
class AnalogueClockAngles {
  final double hourAngle;
  final double minuteAngle;
  final double secondAngle;

  const AnalogueClockAngles({
    required this.hourAngle,
    required this.minuteAngle,
    required this.secondAngle,
  });
}

/// Provides discrete angles for analogue clock hands, with seconds stepping crisply.
final analogueAnglesProvider = Provider.autoDispose<AnalogueClockAngles>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();

  final secondAngle = (time.second / 60.0) * 2 * math.pi;
  final minuteAngle = ((time.minute + time.second / 60.0) / 60.0) * 2 * math.pi;
  final hourAngle =
      (((time.hour % 12) + time.minute / 60.0) / 12.0) * 2 * math.pi;

  return AnalogueClockAngles(
    hourAngle: hourAngle,
    minuteAngle: minuteAngle,
    secondAngle: secondAngle,
  );
});
