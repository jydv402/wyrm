import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Ambient plum gradient backdrop for the full-screen alarm surface.
class AlarmBackdrop extends StatelessWidget {
  /// Whether the pulse overlay should be at full opacity.
  final bool pulseHigh;

  /// Whether animations are disabled, collapsing the opacity duration to zero.
  final bool disableAnimations;

  const AlarmBackdrop({
    super.key,
    required this.pulseHigh,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: AlarmBackdropPainter(intensity: 1.0)),
        AnimatedOpacity(
          opacity: pulseHigh ? 1.0 : 0.45,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 480),
          child: const CustomPaint(
            painter: AlarmBackdropPainter(intensity: 1.4, pulseOverlay: true),
          ),
        ),
      ],
    );
  }
}

/// Paints the two-layer radial plum glow behind the alarm surface.
class AlarmBackdropPainter extends CustomPainter {
  /// Multiplier applied to the accent glow alpha.
  final double intensity;

  /// Whether this layer paints the pulsing accent glow only.
  final bool pulseOverlay;

  const AlarmBackdropPainter({
    required this.intensity,
    this.pulseOverlay = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (!pulseOverlay) {
      canvas.drawRect(rect, Paint()..color = AppColors.background);
      final baseTopGlow = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.15,
          colors: [
            AppColors.plumTop.withValues(alpha: 0.72),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, baseTopGlow);
    }

    final accentGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.35, 0.25),
        radius: 0.95,
        colors: [
          AppColors.plumGlow.withValues(alpha: (0.28 * intensity).clamp(0, 1)),
          AppColors.plumAccent.withValues(
            alpha: (0.08 * intensity).clamp(0, 1),
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, accentGlow);
  }

  @override
  bool shouldRepaint(covariant AlarmBackdropPainter oldDelegate) =>
      oldDelegate.intensity != intensity ||
      oldDelegate.pulseOverlay != pulseOverlay;
}
