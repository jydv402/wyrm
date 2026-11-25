import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Single alphanumeric or space key button for virtual keyboards.
class KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSpacebar;
  final double fontSize;

  const KeyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isSpacebar = false,
    this.fontSize = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.accentOrange.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderDark.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            child: Text(
              isSpacebar ? '' : label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Action key button (e.g. shift, backspace, mode switch, done) with support
/// for labels, icons, accent styling, and active highlight state.
class ActionKeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;
  final Color? activeColor;
  final bool isAccent;

  const ActionKeyButton({
    super.key,
    this.label,
    this.icon,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.activeColor,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAccent
        ? AppColors.cardSage
        : isActive
        ? (activeColor ?? AppColors.accentOrange).withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.04);

    final fgColor = isAccent
        ? AppColors.textOnLight
        : isActive
        ? (activeColor ?? AppColors.accentOrange)
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? (activeColor ?? AppColors.accentOrange)
                    : AppColors.borderDark,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, size: 16, color: fgColor),
                if (icon != null && label != null) const SizedBox(width: 4),
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
