import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyrm_desk/clock/clock_provider.dart';
import 'package:wyrm_desk/core/theme.dart';

/// Horizontal clock layout optimized for medium bento card width and full-screen companion view.
///
/// Places hours and minutes side-by-side rendered with lean, tall Oswald typography,
/// an integrated seconds badge, an AM/PM period indicator, and a countdown to midnight.
class DigitalClockMedium extends StatelessWidget {
  /// Toggles glowing amber/orange nightstand palette for pitch-black ambient viewing.
  final bool isNightstand;

  const DigitalClockMedium({
    super.key,
    this.isNightstand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Horizontal row grouping digital time digits and second indicators.
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ClockHoursDigit(isNightstand: isNightstand),
                  _ClockColonSeparator(isNightstand: isNightstand),
                  _ClockMinutesDigit(isNightstand: isNightstand),
                  const SizedBox(width: 14),
                  _ClockSecondsAndPeriodColumn(isNightstand: isNightstand),
                ],
              ),
              const SizedBox(height: 16),

              // Countdown badge showing remaining time left in the current day.
              _ClockTimeLeftBadge(isNightstand: isNightstand),
            ],
          ),
        ),
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
        fontSize: 114,
        fontWeight: FontWeight.w700,
        height: 0.9,
        letterSpacing: -2.0,
      ),
    );
  }
}

/// Static colon separator dividing hours and minutes.
class _ClockColonSeparator extends StatelessWidget {
  final bool isNightstand;

  const _ClockColonSeparator({this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    final color = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.4)
        : AppColors.textOnLight.withValues(alpha: 0.3);

    return Text(
      ':',
      style: GoogleFonts.oswald(
        color: color,
        fontSize: 100,
        fontWeight: FontWeight.w600,
        height: 0.9,
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
        ? const Color(0xFFFF9500).withValues(alpha: 0.9)
        : AppColors.textOnLight.withValues(alpha: 0.85);

    return Text(
      minutes,
      style: GoogleFonts.oswald(
        color: color,
        fontSize: 114,
        fontWeight: FontWeight.w700,
        height: 0.9,
        letterSpacing: -2.0,
      ),
    );
  }
}

/// Vertical column containing AM/PM tag and the ticking seconds badge.
class _ClockSecondsAndPeriodColumn extends StatelessWidget {
  final bool isNightstand;

  const _ClockSecondsAndPeriodColumn({this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ClockPeriodBadge(isNightstand: isNightstand),
        const SizedBox(height: 6),
        _ClockSecondsBadge(isNightstand: isNightstand),
      ],
    );
  }
}

/// Renders the AM/PM badge in 12-hour mode, rebuilding only when period changes.
class _ClockPeriodBadge extends ConsumerWidget {
  final bool isNightstand;

  const _ClockPeriodBadge({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(clockPeriodProvider);
    if (period == null) return const SizedBox.shrink();

    final bg = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textOnLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        period,
        style: GoogleFonts.oswald(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Renders the stepping seconds badge, updating each second.
class _ClockSecondsBadge extends ConsumerWidget {
  final bool isNightstand;

  const _ClockSecondsBadge({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(clockSecondsProvider);

    final bg = isNightstand ? const Color(0xFFFF9500) : AppColors.accentOrange;
    final textColor = isNightstand ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ':$seconds',
        style: GoogleFonts.oswald(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Renders remaining time until midnight in a tactile hardware-inspired pill badge.
class _ClockTimeLeftBadge extends ConsumerWidget {
  final bool isNightstand;

  const _ClockTimeLeftBadge({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeLeft = ref.watch(timeLeftTodayProvider);

    final bg = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final border = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.8)
        : AppColors.textOnLight.withValues(alpha: 0.75);
    final iconColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.accentOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 13,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            timeLeft,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
