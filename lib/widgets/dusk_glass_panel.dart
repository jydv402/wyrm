import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/theme.dart';

/// Base Dusk Glass surface container featuring tone gradients, 1px glowing edge,
/// upper light sheen, and ambient elevation.
class DuskGlassPanel extends StatelessWidget {
  final DuskTone tone;
  final double borderRadius;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Border? customBorder;
  final Gradient? customGradient;
  final Widget? background;

  const DuskGlassPanel({
    super.key,
    required this.tone,
    this.borderRadius = 32.0,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.width,
    this.height,
    this.customBorder,
    this.customGradient,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final border = customBorder ?? Border.all(color: tone.border, width: 1.0);

    final gradient = customGradient ?? tone.gradient;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: [
          // Deep drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 40.0,
            spreadRadius: -14.0,
            offset: const Offset(0, 24),
          ),
          // Subtle tone ambient glow
          BoxShadow(
            color: tone.glow,
            blurRadius: 36.0,
            spreadRadius: -8.0,
            offset: Offset.zero,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Background layer (e.g. dynamic time-of-day photo, persistent wallpaper)
          if (background != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: background!,
              ),
            ),

          // Soft light sheen falling across the top edge of the glass surface
          Positioned(
            top: 1,
            left: 1,
            right: 1,
            height: 110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius - 1),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main child content
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
