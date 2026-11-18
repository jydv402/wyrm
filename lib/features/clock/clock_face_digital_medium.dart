import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_numeral.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

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
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Hours(tone: tone),
                Text(':', style: ClockNumeral.display(100, tone.inkMuted)),
                _Minutes(tone: tone),
                const SizedBox(width: 16),
                _SecondsAndPeriod(tone: tone),
              ],
            ),
            const SizedBox(height: 16),
            const _Countdown(),
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
    style: ClockNumeral.display(114, tone.ink),
  );
}

class _Minutes extends ConsumerWidget {
  final ClockTone tone;

  const _Minutes({required this.tone});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    ref.watch(clockMinutesProvider),
    style: ClockNumeral.display(114, tone.ink),
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
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(':$seconds', style: ClockNumeral.meta(22, tone.inkSecondary)),
      ],
    );
  }
}

class _Countdown extends ConsumerWidget {
  const _Countdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(timeLeftTodayPartsProvider);
    return DuskGlassPill.sunCountdown(
      timeLeft: '${left.hours}h ${left.minutes}m',
      suffix: 'left today',
    );
  }
}
