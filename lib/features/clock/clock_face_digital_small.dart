import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_numeral.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Compact vertical face: the date, the stacked time, the countdown.
///
/// The digits are the one bright element; the date and the countdown sit quiet
/// above and below them.
class DigitalClockSmall extends ConsumerWidget {
  const DigitalClockSmall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tone = ClockTone.standard;
    final date = ref.watch(clockDateProvider);
    final hours = ref.watch(clockHoursProvider);
    final minutes = ref.watch(clockMinutesProvider);
    final left = ref.watch(timeLeftTodayPartsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          date,
          style: TextStyle(
            color: tone.inkSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hours, style: ClockNumeral.display(126, tone.ink)),
                Text(minutes, style: ClockNumeral.display(126, tone.ink)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 44,
                  height: 2,
                  child: ColoredBox(color: tone.hairline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DuskGlassPill.sunCountdown(
          timeLeft: '${left.hours}h ${left.minutes}m',
          suffix: 'left today',
        ),
      ],
    );
  }
}
