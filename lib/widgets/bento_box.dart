import 'package:material_ui/material_ui.dart';

/// Reusable base container matching the bento box corner radiuses and styling.
class BentoBox extends StatelessWidget {
  final Color color;
  final double borderRadius;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final double? width;
  final double? height;

  const BentoBox({
    super.key,
    required this.color,
    this.borderRadius = 30.0,
    this.child,
    this.padding,
    this.margin,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
