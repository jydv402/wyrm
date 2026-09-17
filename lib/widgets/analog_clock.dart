import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/clock/clock_provider.dart';
import 'package:wyrm_desk/core/theme.dart';

/// Squircle-shaped analogue clock designed in the retro-minimalist Dieter Rams hardware aesthetic.
class AnalogClock extends ConsumerWidget {
  /// Dimension of the squircle clock container.
  final double? size;

  /// Toggles glowing amber/orange nightstand palette for pitch-black ambient viewing.
  final bool isNightstand;

  const AnalogClock({
    super.key,
    this.size,
    this.isNightstand = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final angles = ref.watch(analogueAnglesProvider);

    final containerColor = isNightstand ? Colors.black : AppColors.surface;
    final borderColor = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.25)
        : AppColors.borderDark;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(32.0),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: CustomPaint(
        painter: _AnalogueClockPainter(
          angles: angles,
          isNightstand: isNightstand,
        ),
      ),
    );
  }
}

/// Custom painter rendering the retro minimalist dial and discrete stepping clock hands.
class _AnalogueClockPainter extends CustomPainter {
  final AnalogueClockAngles angles;
  final bool isNightstand;

  _AnalogueClockPainter({
    required this.angles,
    this.isNightstand = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final Color majorTickColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textPrimary;
    final Color minorTickColor = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.4)
        : AppColors.textSecondary.withValues(alpha: 0.5);
    final Color handColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textPrimary;
    final Color innerCapColor = isNightstand
        ? Colors.black
        : AppColors.surface;

    // Render 12 circular hour markers around the dial perimeter.
    final tickPaint = Paint()
      ..color = minorTickColor
      ..style = PaintingStyle.fill;

    final majorTickPaint = Paint()
      ..color = majorTickColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12.0) * 2 * math.pi;
      final isMajor = i % 3 == 0;
      final markerRadius = isMajor ? 3.0 : 1.8;
      final tickOffset = Offset(
        center.dx + (radius - 12) * math.cos(angle - math.pi / 2),
        center.dy + (radius - 12) * math.sin(angle - math.pi / 2),
      );
      canvas.drawCircle(
        tickOffset,
        markerRadius,
        isMajor ? majorTickPaint : tickPaint,
      );
    }

    // Render hour hand.
    final hourHandPaint = Paint()
      ..color = handColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final hourLength = radius * 0.48;
    final hourEnd = Offset(
      center.dx + hourLength * math.cos(angles.hourAngle - math.pi / 2),
      center.dy + hourLength * math.sin(angles.hourAngle - math.pi / 2),
    );
    canvas.drawLine(center, hourEnd, hourHandPaint);

    // Render minute hand.
    final minuteHandPaint = Paint()
      ..color = handColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final minuteLength = radius * 0.72;
    final minuteEnd = Offset(
      center.dx + minuteLength * math.cos(angles.minuteAngle - math.pi / 2),
      center.dy + minuteLength * math.sin(angles.minuteAngle - math.pi / 2),
    );
    canvas.drawLine(center, minuteEnd, minuteHandPaint);

    // Render safety orange second hand with counterweight tail.
    final secondHandPaint = Paint()
      ..color = AppColors.accentOrange
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final secondLength = radius * 0.82;
    final secondTail = radius * 0.18;
    final secondEnd = Offset(
      center.dx + secondLength * math.cos(angles.secondAngle - math.pi / 2),
      center.dy + secondLength * math.sin(angles.secondAngle - math.pi / 2),
    );
    final secondStart = Offset(
      center.dx - secondTail * math.cos(angles.secondAngle - math.pi / 2),
      center.dy - secondTail * math.sin(angles.secondAngle - math.pi / 2),
    );
    canvas.drawLine(secondStart, secondEnd, secondHandPaint);

    // Render center pivot cap dot.
    final centerCapPaint = Paint()
      ..color = isNightstand ? const Color(0xFFFF9500) : AppColors.accentOrange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, centerCapPaint);

    final innerCenterCap = Paint()
      ..color = innerCapColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.8, innerCenterCap);
  }

  @override
  bool shouldRepaint(covariant _AnalogueClockPainter oldDelegate) {
    return oldDelegate.angles.secondAngle != angles.secondAngle ||
        oldDelegate.angles.minuteAngle != angles.minuteAngle ||
        oldDelegate.angles.hourAngle != angles.hourAngle ||
        oldDelegate.isNightstand != isNightstand;
  }
}
