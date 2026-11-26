import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Large rounded alarm action button (Cancel / Snooze).
class AlarmActionButton extends StatelessWidget {
  /// Minimum tap-target height.
  final double minHeight;

  /// Fill colour.
  final Color backgroundColor;

  /// Icon and label colour.
  final Color foregroundColor;

  /// Optional border colour.
  final Color? borderColor;

  /// Optional outer glow colour.
  final Color? glowColor;

  /// Leading icon.
  final IconData icon;

  /// Icon size in logical pixels.
  final double iconSize;

  /// Button label.
  final String label;

  /// Label font size.
  final double fontSize;

  /// Label font weight.
  final FontWeight fontWeight;

  /// Invoked on tap.
  final VoidCallback onPressed;

  const AlarmActionButton({
    super.key,
    required this.minHeight,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.fontSize,
    required this.fontWeight,
    required this.onPressed,
    this.borderColor,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24.0),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.5)
                  : null,
              boxShadow: glowColor != null
                  ? [
                      BoxShadow(
                        color: glowColor!,
                        blurRadius: 24.0,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12.0,
              children: [
                Icon(icon, size: iconSize, color: foregroundColor),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cancel-on-top, Snooze-below stack shared by both alarm layouts.
class AlarmButtonsColumn extends StatelessWidget {
  /// Snooze duration shown in the button label.
  final int snoozeMinutes;

  /// Stops the alarm and completes the occurrence.
  final VoidCallback onDismiss;

  /// Stops the alarm and reschedules it.
  final VoidCallback onSnooze;

  const AlarmButtonsColumn({
    super.key,
    required this.snoozeMinutes,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14.0,
      children: [
        AlarmActionButton(
          key: const ValueKey<String>('alarm_cancel_button'),
          minHeight: 96.0,
          backgroundColor: AppColors.plumFill,
          foregroundColor: AppColors.plumInk,
          glowColor: AppColors.plumFill.withValues(alpha: 0.45),
          icon: Icons.alarm_off_rounded,
          iconSize: 30.0,
          label: 'Cancel',
          fontSize: 24.0,
          fontWeight: FontWeight.w800,
          onPressed: onDismiss,
        ),
        AlarmActionButton(
          key: const ValueKey<String>('alarm_snooze_button'),
          minHeight: 76.0,
          backgroundColor: AppColors.plumTop.withValues(alpha: 0.72),
          foregroundColor: AppColors.textPrimary,
          borderColor: AppColors.plumAccent.withValues(alpha: 0.42),
          icon: Icons.snooze_rounded,
          iconSize: 24.0,
          label: 'Snooze ${snoozeMinutes}m',
          fontSize: 19.0,
          fontWeight: FontWeight.w700,
          onPressed: onSnooze,
        ),
      ],
    );
  }
}
