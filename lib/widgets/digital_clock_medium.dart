import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyrm_desk/clock/clock_provider.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Horizontal clock layout optimized for medium bento card width and full-screen companion view.
class DigitalClockMedium extends StatelessWidget {
  final bool isNightstand;

  const DigitalClockMedium({super.key, this.isNightstand = false});

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

class _ClockHoursDigit extends ConsumerWidget {
  final bool isNightstand;

  const _ClockHoursDigit({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(clockHoursProvider);
    final color = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textPrimary;

    return Text(
      hours,
      style: GoogleFonts.barlowCondensed(
        color: color,
        fontSize: 114,
        fontWeight: FontWeight.w700,
        height: 0.9,
        letterSpacing: -2.0,
      ),
    );
  }
}

class _ClockColonSeparator extends StatelessWidget {
  final bool isNightstand;

  const _ClockColonSeparator({this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    final color = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.4)
        : AppColors.textSecondary.withValues(alpha: 0.4);

    return Text(
      ':',
      style: GoogleFonts.barlowCondensed(
        color: color,
        fontSize: 100,
        fontWeight: FontWeight.w600,
        height: 0.9,
      ),
    );
  }
}

class _ClockMinutesDigit extends ConsumerWidget {
  final bool isNightstand;

  const _ClockMinutesDigit({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(clockMinutesProvider);
    final color = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textPrimary;

    return Text(
      minutes,
      style: GoogleFonts.barlowCondensed(
        color: color,
        fontSize: 114,
        fontWeight: FontWeight.w700,
        height: 0.9,
        letterSpacing: -2.0,
      ),
    );
  }
}

class _ClockSecondsAndPeriodColumn extends ConsumerWidget {
  final bool isNightstand;

  const _ClockSecondsAndPeriodColumn({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(clockSecondsProvider);
    final period = ref.watch(clockPeriodProvider);

    final primaryColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.slate.accent;
    final secondaryColor = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.6)
        : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (period != null)
          Text(
            period,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        Text(
          ':$seconds',
          style: TextStyle(
            color: secondaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ClockTimeLeftBadge extends ConsumerWidget {
  final bool isNightstand;

  const _ClockTimeLeftBadge({this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(timeLeftTodayPartsProvider);

    return DuskGlassPill.sunCountdown(
      timeLeft: '${left.hours}h ${left.minutes}m',
      suffix: 'left today',
    );
  }
}
