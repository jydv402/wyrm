import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';

/// Column displaying remaining daylight/day hours and the 'left today' indicator.
class ClockSunCountdown extends ConsumerWidget {
  /// Whether to render in amber nightstand mode.
  final bool isNightstand;

  const ClockSunCountdown({super.key, this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(timeLeftTodayPartsProvider);
    final tone = ClockTone.of(isNightstand);

    return Padding(
      padding: const EdgeInsets.only(left: 6.0, bottom: 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: .start,
        spacing: 2,
        children: [
          Text(
            '${left.hours}h ${left.minutes}m',
            style: TextStyle(
              color: tone.accent,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          Text(
            'left today',
            style: TextStyle(
              color: tone.inkSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
