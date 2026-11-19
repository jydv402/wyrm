import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/clock/clock_face_analog.dart';
import 'package:wyrm_desk/features/clock/clock_face_digital_medium.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';

/// Fullscreen companion: the analogue dial, a hairline seam, the digital time.
class ClockFullscreenView extends StatelessWidget {
  /// Amber-on-black palette for the nightstand tier.
  final bool isNightstand;

  const ClockFullscreenView({super.key, this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    final tone = ClockTone.of(isNightstand);
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: AnalogClock(isNightstand: isNightstand),
            ),
          ),
        ),

        // Hardware seam: one hairline separating the two instruments.
        SizedBox(
          width: 1,
          height: 280,
          child: ColoredBox(color: tone.hairline),
        ),

        Expanded(
          flex: 6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DigitalClockMedium(isNightstand: isNightstand),
            ),
          ),
        ),
      ],
    );
  }
}
