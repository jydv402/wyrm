import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders atmospheric layered mountain ridge silhouettes and a radiant glowing sun,
/// matching the Dusk Glass aesthetic in assets/web and the reference screenshot.
class DuskMountainBackdrop extends StatelessWidget {
  final Color sunColor;
  final Color sunGlowColor;
  final Color ridgeNearColor;
  final Color ridgeMidColor;
  final Color ridgeFarColor;
  final bool showSun;
  final double height;

  const DuskMountainBackdrop({
    super.key,
    this.sunColor = const Color(0xFFF2A768),
    this.sunGlowColor = const Color(0x33F2A768),
    this.ridgeNearColor = const Color(0xFF070A0D),
    this.ridgeMidColor = const Color(0xFF0F151A),
    this.ridgeFarColor = const Color(0xFF172027),
    this.showSun = true,
    this.height = 180.0,
  });

  /// Factory preset matching the Clock card's sunset horizon.
  factory DuskMountainBackdrop.clock({double height = 200.0}) {
    return DuskMountainBackdrop(
      sunColor: const Color(0xFFF6C18E),
      sunGlowColor: const Color(0x55F2A768),
      ridgeNearColor: const Color(0xFF05080B),
      ridgeMidColor: const Color(0xFF0D1318),
      ridgeFarColor: const Color(0xFF141C23),
      showSun: true,
      height: height,
    );
  }

  /// Factory preset matching the Tasks card's warm ember mountain ridge.
  factory DuskMountainBackdrop.tasks({double height = 180.0}) {
    return DuskMountainBackdrop(
      sunColor: const Color(0xFFF27C52),
      sunGlowColor: const Color(0x33DC582B),
      ridgeNearColor: const Color(0xFF120906),
      ridgeMidColor: const Color(0xFF1E100A),
      ridgeFarColor: const Color(0xFF2A170F),
      showSun: false,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MountainBackdropPainter(
          sunColor: sunColor,
          sunGlowColor: sunGlowColor,
          ridgeNearColor: ridgeNearColor,
          ridgeMidColor: ridgeMidColor,
          ridgeFarColor: ridgeFarColor,
          showSun: showSun,
        ),
      ),
    );
  }
}

class _MountainBackdropPainter extends CustomPainter {
  final Color sunColor;
  final Color sunGlowColor;
  final Color ridgeNearColor;
  final Color ridgeMidColor;
  final Color ridgeFarColor;
  final bool showSun;

  _MountainBackdropPainter({
    required this.sunColor,
    required this.sunGlowColor,
    required this.ridgeNearColor,
    required this.ridgeMidColor,
    required this.ridgeFarColor,
    required this.showSun,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sun & Radiant Atmospheric Glow
    if (showSun) {
      final sunCenter = Offset(w * 0.62, h * 0.44);
      final sunRadius = math.min(w, h) * 0.16;

      // Broad ambient glow
      final broadGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            sunGlowColor.withValues(alpha: 0.45),
            sunGlowColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius * 3.5));
      canvas.drawCircle(sunCenter, sunRadius * 3.5, broadGlowPaint);

      // Core sun disc with soft halo
      final sunPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            sunColor.withValues(alpha: 0.95),
            sunColor.withValues(alpha: 0.70),
            sunColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
      canvas.drawCircle(sunCenter, sunRadius, sunPaint);
    }

    // 2. Far Ridge Layer
    final farPath = Path();
    farPath.moveTo(0, h * 0.60);
    farPath.cubicTo(w * 0.15, h * 0.48, w * 0.35, h * 0.58, w * 0.52, h * 0.44);
    farPath.cubicTo(w * 0.68, h * 0.32, w * 0.82, h * 0.46, w, h * 0.40);
    farPath.lineTo(w, h);
    farPath.lineTo(0, h);
    farPath.close();

    final farPaint = Paint()
      ..color = ridgeFarColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(farPath, farPaint);

    // 3. Mid Ridge Layer
    final midPath = Path();
    midPath.moveTo(0, h * 0.68);
    midPath.cubicTo(w * 0.18, h * 0.56, w * 0.32, h * 0.68, w * 0.48, h * 0.52);
    midPath.cubicTo(w * 0.62, h * 0.38, w * 0.78, h * 0.62, w * 0.90, h * 0.50);
    midPath.lineTo(w, h * 0.54);
    midPath.lineTo(w, h);
    midPath.lineTo(0, h);
    midPath.close();

    final midPaint = Paint()
      ..color = ridgeMidColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(midPath, midPaint);

    // 4. Near Foreground Ridge Layer
    final nearPath = Path();
    nearPath.moveTo(0, h * 0.78);
    nearPath.cubicTo(w * 0.14, h * 0.66, w * 0.28, h * 0.78, w * 0.44, h * 0.62);
    nearPath.cubicTo(w * 0.60, h * 0.50, w * 0.74, h * 0.70, w * 0.86, h * 0.58);
    nearPath.cubicTo(w * 0.94, h * 0.52, w * 0.98, h * 0.56, w, h * 0.60);
    nearPath.lineTo(w, h);
    nearPath.lineTo(0, h);
    nearPath.close();

    final nearPaint = Paint()
      ..color = ridgeNearColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(nearPath, nearPaint);
  }

  @override
  bool shouldRepaint(covariant _MountainBackdropPainter oldDelegate) {
    return oldDelegate.sunColor != sunColor ||
        oldDelegate.ridgeNearColor != ridgeNearColor ||
        oldDelegate.showSun != showSun;
  }
}
