import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_numeral.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';

/// Compact vertical face: stacked hours and minutes plus the dedicated seconds
/// and period telemetry row.
///
/// Designed to occupy the small card tier with bold condensed numerals while
/// keeping secondary instruments quiet and tabular. The daylight countdown is
/// the card's, not the face's - see `ClockContainer`.
class DigitalClockSmall extends ConsumerWidget {
  const DigitalClockSmall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tone = ClockTone.standard;
    final hours = ref.watch(clockHoursProvider);
    final minutes = ref.watch(clockMinutesProvider);
    final seconds = ref.watch(clockSecondsProvider);
    final period = ref.watch(clockPeriodProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hours, style: ClockNumeral.display(150, tone.ink)),
                Text(minutes, style: ClockNumeral.display(150, tone.ink)),
                // Dedicated telemetry row: period badge and live ticking seconds
                const SizedBox(height: 8.0),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 8.0,
                  children: [
                    Text(
                      ' : $seconds',
                      style: ClockNumeral.display(50, tone.inkSecondary),
                    ),
                    if (period != null) ...[
                      Text(
                        period,
                        style: TextStyle(
                          color: tone.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
