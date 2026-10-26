import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';

/// Translucent pill container for status, priorities, tags, and metrics.
class DuskGlassPill extends StatelessWidget {
  final Widget? icon;
  final Widget child;
  final Color? tintColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double height;
  final bool borderless;

  const DuskGlassPill({
    super.key,
    this.icon,
    required this.child,
    this.tintColor,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0),
    this.height = 32.0,
    this.borderless = false,
  });

  /// Factory preset for the Clock card's sunset countdown pill ("2h 48m left today").
  factory DuskGlassPill.sunCountdown({
    required String timeLeft,
    required String suffix,
    VoidCallback? onTap,
  }) {
    return DuskGlassPill(
      onTap: onTap,
      tintColor: const Color(0xFFF2A768),
      height: 38.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      icon: const Icon(
        Icons.wb_sunny_outlined,
        size: 16,
        color: Color(0xFFF2A768),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeLeft,
            style: const TextStyle(
              color: Color(0xFFF2A768),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffix,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Factory preset for Task priority badges (High, Medium, Low).
  factory DuskGlassPill.priority(String priority) {
    final Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = AppColors.priorityHigh;
        break;
      case 'medium':
        color = AppColors.priorityMedium;
        break;
      case 'low':
      default:
        color = AppColors.priorityLow;
        break;
    }

    return DuskGlassPill(
      tintColor: color,
      height: 24.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? AppColors.textSecondary;
    final bgColor = tint.withValues(alpha: 0.12);
    final borderColor = borderless ? Colors.transparent : tint.withValues(alpha: 0.28);

    final content = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            child,
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(height / 2),
        child: content,
      ),
    );
  }
}
