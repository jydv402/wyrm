import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyrm_desk/clock/clock_provider.dart';
import 'package:wyrm_desk/core/theme.dart';

/// Vertical clock layout optimized for compact bento placement.
///
/// Features vertically stacked hours and minutes rendered with lean, tall Oswald typography,
/// an integrated seconds and AM/PM badge row, and a midnight countdown status line.
class DigitalClockSmall extends StatelessWidget {
  /// Toggles glowing amber/orange nightstand palette for pitch-black ambient viewing.
  final bool isNightstand;

  const DigitalClockSmall({
    super.key,
    this.isNightstand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top breathing spacer maintaining alignment below the corner button.
          const SizedBox(height: 16),

          // Vertically stacked digital time typography utilizing maximum card area.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ClockHoursDigit(isNightstand: isNightstand),
                    _ClockMinutesDigit(isNightstand: isNightstand),
                  ],
                ),
              ),
            ),
          ),

          // Bottom section hosting seconds, AM/PM period, and remaining time.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ClockSecondsAndPeriodRow(isNightstand: isNightstand),
              const SizedBox(height: 8),
              _ClockTimeLeftLabel(isNightstand: isNightstand),
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders the hour digits, rebuilding strictly when the hour changes.
class _ClockHoursDigit extends ConsumerWidget {
  final bool isNightstand;

  const _ClockHoursDigit({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(clockHoursProvider);
    final color = isNightstand ? const Color(0xFFFF9500) : AppColors.textOnLight;

    return Text(
      hours,
      style: GoogleFonts.oswald(
        color: color,
        fontSize: 96,
        fontWeight: FontWeight.w700,
        height: 0.88,
        letterSpacing: -1.0,
      ),
    );
  }
}

/// Renders the minute digits, rebuilding strictly when the minute changes.
class _ClockMinutesDigit extends ConsumerWidget {
  final bool isNightstand;

  const _ClockMinutesDigit({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(clockMinutesProvider);
    final color = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.85)
        : AppColors.textOnLight.withValues(alpha: 0.85);

    return Text(
      minutes,
      style: GoogleFonts.oswald(
        color: color,
        fontSize: 96,
        fontWeight: FontWeight.w700,
        height: 0.88,
        letterSpacing: -1.0,
      ),
    );
  }
}

/// Renders seconds and AM/PM status badge, with seconds ticking each second.
class _ClockSecondsAndPeriodRow extends ConsumerWidget {
  final bool isNightstand;

  const _ClockSecondsAndPeriodRow({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(clockSecondsProvider);
    final period = ref.watch(clockPeriodProvider);

    final secondsBg = isNightstand ? const Color(0xFFFF9500) : AppColors.accentOrange;
    final secondsTextColor = isNightstand ? Colors.black : Colors.white;

    final periodBg = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);
    final periodTextColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textOnLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: secondsBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            ':$seconds',
            style: GoogleFonts.oswald(
              color: secondsTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (period != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: periodBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              period,
              style: GoogleFonts.oswald(
                color: periodTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Renders remaining time until midnight, updating only once per minute.
class _ClockTimeLeftLabel extends ConsumerWidget {
  final bool isNightstand;

  const _ClockTimeLeftLabel({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeLeft = ref.watch(timeLeftTodayProvider);
    final color = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.6)
        : AppColors.textOnLight.withValues(alpha: 0.6);

    return Text(
      timeLeft,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}
