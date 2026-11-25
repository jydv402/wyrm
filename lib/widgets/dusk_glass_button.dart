import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Interactive Dusk Glass button with tactile press scaling and subtle glowing borders.
class DuskGlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? label;
  final bool isPrimary;
  final Color? primaryColor;
  final Color? primaryForegroundColor;
  final double height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isActive;

  const DuskGlassButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.isPrimary = false,
    this.primaryColor,
    this.primaryForegroundColor,
    this.height = 42.0,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 18.0),
    this.borderRadius = 999.0,
    this.isActive = false,
  });

  /// Circular icon button preset (e.g. settings, sliders, add, chevrons).
  factory DuskGlassButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    bool isPrimary = false,
    Color? primaryColor,
    Color? primaryForegroundColor,
    double size = 42.0,
    bool isActive = false,
  }) {
    return DuskGlassButton(
      key: key,
      onPressed: onPressed,
      icon: icon,
      isPrimary: isPrimary,
      primaryColor: primaryColor,
      primaryForegroundColor: primaryForegroundColor,
      height: size,
      width: size,
      padding: EdgeInsets.zero,
      borderRadius: size / 2,
      isActive: isActive,
    );
  }

  @override
  State<DuskGlassButton> createState() => _DuskGlassButtonState();
}

class _DuskGlassButtonState extends State<DuskGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    final Color bgColor;
    final Border? border;
    final List<BoxShadow>? shadow;

    if (widget.isPrimary) {
      final fill = widget.primaryColor ?? AppColors.slate.fill;
      bgColor = isEnabled ? fill : fill.withValues(alpha: 0.4);
      border = null;
      shadow = isEnabled
          ? [
              BoxShadow(
                color: fill.withValues(alpha: 0.45),
                blurRadius: 14.0,
                offset: const Offset(0, 4),
              ),
            ]
          : null;
    } else if (widget.isActive) {
      bgColor = AppColors.slate.accent.withValues(alpha: 0.16);
      border = Border.all(
        color: AppColors.slate.accent.withValues(alpha: 0.5),
        width: 1.0,
      );
      shadow = null;
    } else {
      bgColor = isEnabled
          ? AppColors.glass
          : AppColors.glass.withValues(alpha: 0.02);
      border = Border.all(
        color: isEnabled ? AppColors.lineStrong : AppColors.line,
        width: 1.0,
      );
      shadow = null;
    }

    final double? effectiveWidth =
        widget.width ??
        ((widget.label == null && widget.icon != null) ? widget.height : null);
    final effectiveBorderRadius =
        (effectiveWidth != null && widget.borderRadius >= widget.height / 2)
        ? widget.height / 2
        : widget.borderRadius;

    final Widget content;
    if (widget.icon != null && widget.label != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          widget.icon!,
          const SizedBox(width: 8),
          Flexible(child: widget.label!),
        ],
      );
    } else if (widget.icon != null) {
      content = Center(child: widget.icon!);
    } else if (widget.label != null) {
      content = Center(child: widget.label!);
    } else {
      content = const SizedBox.shrink();
    }

    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final targetScale = (isEnabled && _isPressed && !disableMotion)
        ? 0.94
        : 1.0;
    final motion = _isPressed
        ? const Motion.snappySpring(duration: Duration(milliseconds: 120))
        : const Motion.bouncySpring(
            duration: Duration(milliseconds: 320),
            extraBounce: 0.1,
          );

    return SingleMotionBuilder(
      value: targetScale,
      motion: disableMotion ? const Motion.none() : motion,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: SizedBox(
            height: widget.height,
            width: effectiveWidth,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(effectiveBorderRadius),
                border: border,
                boxShadow: shadow,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
