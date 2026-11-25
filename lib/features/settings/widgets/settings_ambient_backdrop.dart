import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Ambient glow background matching Wyrm Desk canvas.
class SettingsAmbientBackdrop extends StatelessWidget {
  const SettingsAmbientBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: SettingsBackdropPainter());
  }
}

/// Custom painter rendering ambient radial gradients behind settings.
class SettingsBackdropPainter extends CustomPainter {
  const SettingsBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Void base
    canvas.drawRect(rect, Paint()..color = AppColors.background);

    // Glow 1: Top-Left Slate / Amber glow
    final glow1Paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.9),
        radius: 0.95,
        colors: [
          AppColors.glacier.accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glow1Paint);

    // Glow 2: Bottom-Right Rust / Ember glow
    final glow2Paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, 0.95),
        radius: 0.85,
        colors: [
          AppColors.rust.accent.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glow2Paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
