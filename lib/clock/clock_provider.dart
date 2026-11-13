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

/// Computes the hours and minutes remaining until midnight of [time]'s civil day.
({int hours, int minutes}) timeLeftUntilMidnight(DateTime time) {
  final endOfDay = DateTime(time.year, time.month, time.day + 1);
  final difference = endOfDay.difference(time);
  return (hours: difference.inHours, minutes: difference.inMinutes % 60);
}

/// Granular provider emitting the raw countdown parts until midnight,
/// rebuilding only once per minute alongside the clock minute tick.
final timeLeftTodayPartsProvider =
    Provider.autoDispose<({int hours, int minutes})>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  return timeLeftUntilMidnight(time);
});

/// Granular provider calculating the formatted remaining time until midnight,
/// updating only once per minute.
final timeLeftTodayProvider = Provider.autoDispose<String>((ref) {
  final left = ref.watch(timeLeftTodayPartsProvider);
  return '${left.hours}h ${left.minutes}m left today';
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

/// Granular provider mapping the current hour to the corresponding time-of-day backdrop image.
///
/// Schedule:
/// - 04:00 - 06:59: clock_1.png (Early morning fog)
/// - 07:00 - 10:59: clock_2.png (Morning after sunrise)
/// - 11:00 - 15:59: clock_3.png (Midday / noon)
/// - 16:00 - 18:59: clock_4.png (Golden hour)
/// - 19:00 - 03:59: clock_5.png (Night)
final clockBackgroundAssetProvider = Provider.autoDispose<String>((ref) {
  final time = ref.watch(clockTimeProvider).value ?? DateTime.now();
  final hour = time.hour;

  if (hour >= 4 && hour < 7) {
    return 'assets/card_bg/clock/clock_1.png';
  } else if (hour >= 7 && hour < 11) {
    return 'assets/card_bg/clock/clock_2.png';
  } else if (hour >= 11 && hour < 16) {
    return 'assets/card_bg/clock/clock_3.png';
  } else if (hour >= 16 && hour < 19) {
    return 'assets/card_bg/clock/clock_4.png';
  } else {
    return 'assets/card_bg/clock/clock_5.png';
  }
});
