import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/clock/clock_face_analog.dart';
import 'package:wyrm_desk/features/clock/clock_face_digital_medium.dart';

/// Fullscreen companion: the analogue dial, a hairline seam, the digital time.
class ClockFullscreenView extends StatelessWidget {
  /// Amber-on-black palette for the nightstand tier.
  final bool isNightstand;

  const ClockFullscreenView({super.key, this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Center(child: DigitalClockMedium(isNightstand: isNightstand)),
        ),
        Expanded(
          flex: 1,
          child: Center(child: AnalogClock(isNightstand: isNightstand)),
        ),
      ],
    );
  }
}
