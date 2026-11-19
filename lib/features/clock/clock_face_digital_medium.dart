import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_numeral.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/clock/clock_sun_countdown.dart';

/// Horizontal face: hours, minutes, seconds, and the countdown beneath them.
///
/// Used by the medium tier and by the right-hand column of the fullscreen tier.
class DigitalClockMedium extends StatelessWidget {
  /// Amber-on-black palette for the nightstand tier.
  final bool isNightstand;

  const DigitalClockMedium({super.key, this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    final tone = ClockTone.of(isNightstand);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 36.0,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: .end,
              children: [
                _Hours(tone: tone),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    ':',
                    style: ClockNumeral.display(150, tone.inkMuted),
                  ),
                ),
                _Minutes(tone: tone),
                const SizedBox(width: 20),
                _SecondsAndPeriod(tone: tone),
              ],
            ),

            ClockSunCountdown(
              isNightstand: isNightstand,
              crossAxisAlignment: CrossAxisAlignment.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hours extends ConsumerWidget {
  final ClockTone tone;

  const _Hours({required this.tone});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    ref.watch(clockHoursProvider),
    style: ClockNumeral.display(172, tone.ink),
  );
}

class _Minutes extends ConsumerWidget {
  final ClockTone tone;

  const _Minutes({required this.tone});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    ref.watch(clockMinutesProvider),
    style: ClockNumeral.display(172, tone.ink),
  );
}

/// The seconds ticking beside the time, with the period above them.
class _SecondsAndPeriod extends ConsumerWidget {
  final ClockTone tone;

  const _SecondsAndPeriod({required this.tone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(clockSecondsProvider);
    final period = ref.watch(clockPeriodProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (period != null)
          Text(
            period,
            style: TextStyle(
              color: tone.accent,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        Text(': $seconds', style: ClockNumeral.display(81, tone.inkSecondary)),
        const SizedBox(height: 4),
      ],
    );
  }
}
