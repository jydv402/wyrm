import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';

/// Clean, quiet date readout positioned at the top of the clock card across all tiers.
class ClockDateLine extends ConsumerWidget {
  /// Whether to use the amber nightstand palette.
  final bool isNightstand;

  const ClockDateLine({super.key, this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(clockDateProvider);
    final tone = ClockTone.of(isNightstand);

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        date,
        style: TextStyle(
          color: tone.inkSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
