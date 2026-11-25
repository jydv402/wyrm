import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

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

  /// Factory preset for Task priority badges (Normal, High, Medium, Low).
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
        color = AppColors.priorityLow;
        break;
      case 'normal':
      default:
        color = AppColors.teal.accent;
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
    final borderColor = borderless
        ? Colors.transparent
        : tint.withValues(alpha: 0.28);

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
          spacing: 8.0,
          children: [?icon, child],
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
