import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// "ALARM RINGING" badge plus the live wall clock with seconds.
class AlarmStatusHeader extends StatelessWidget {
  /// Current wall-clock instant.
  final DateTime now;

  /// Whether to render the clock in 24-hour format.
  final bool is24Hour;

  /// Whether the status dot is at full opacity.
  final bool pulseHigh;

  /// Whether animations are disabled.
  final bool disableAnimations;

  const AlarmStatusHeader({
    super.key,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final period = is24Hour ? null : (now.hour >= 12 ? 'PM' : 'AM');
    final displayHour = is24Hour
        ? now.hour
        : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    final hourLabel = is24Hour
        ? displayHour.toString().padLeft(2, '0')
        : '$displayHour';
    final minuteLabel = now.minute.toString().padLeft(2, '0');
    final secondsLabel = now.second.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14.0,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: AppColors.plumAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(
              color: AppColors.plumAccent.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10.0,
            children: [
              AnimatedOpacity(
                opacity: pulseHigh ? 1.0 : 0.45,
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                child: Container(
                  width: 10.0,
                  height: 10.0,
                  decoration: const BoxDecoration(
                    color: AppColors.plumAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Text(
                'ALARM RINGING',
                style: TextStyle(
                  color: AppColors.plumAccent,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 6.0,
            children: [
              Text(
                '$hourLabel:$minuteLabel',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 44.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ':$secondsLabel',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (period != null)
                Text(
                  period,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
