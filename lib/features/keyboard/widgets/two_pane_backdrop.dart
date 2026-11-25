import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Atmospheric dusk ambient backdrop tinted with tone.
class TwoPaneAmbientBackdrop extends StatelessWidget {
  final DuskTone tone;

  const TwoPaneAmbientBackdrop({super.key, required this.tone});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TwoPaneBackdropPainter(tone: tone),
      size: Size.infinite,
    );
  }
}

/// Custom painter rendering ambient radial gradients behind the two-pane editor.
class TwoPaneBackdropPainter extends CustomPainter {
  final DuskTone tone;

  const TwoPaneBackdropPainter({required this.tone});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Void base
    canvas.drawRect(rect, Paint()..color = AppColors.background);

    // Glow 1: Top-Left subtle tone glow
    final glow1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.9),
        radius: 1.0,
        colors: [tone.accent.withValues(alpha: 0.10), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glow1);

    // Glow 2: Bottom-Right ambient tone glow
    final glow2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, 0.95),
        radius: 0.9,
        colors: [tone.glow.withValues(alpha: 0.18), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glow2);
  }

  @override
  bool shouldRepaint(covariant TwoPaneBackdropPainter oldDelegate) =>
      oldDelegate.tone != tone;
}
