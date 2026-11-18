import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';

/// Squircle analogue dial in the Rams instrument idiom.
///
/// The dial answers one question - what time is it - with dots rather than
/// numerals, so it stays legible across the room.
class AnalogClock extends ConsumerWidget {
  /// Outer dimension of the squircle carriage.
  final double? size;

  /// Amber-on-black palette for the nightstand tier.
  final bool isNightstand;

  const AnalogClock({super.key, this.size, this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ClockTone.of(isNightstand);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.dial,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tone.rim, width: 1.5),
      ),
      child: CustomPaint(
        painter: _DialPainter(
          angles: ref.watch(clockHandAnglesProvider),
          isNightstand: isNightstand,
        ),
      ),
    );
  }
}

/// Draws the 12 hour markers, three hands and the centre cap.
///
/// Paints are built once per painter rather than per frame, so [paint] only
/// draws.
class _DialPainter extends CustomPainter {
  final ClockHandAngles angles;
  final bool isNightstand;

  final Paint _marker = Paint()..style = PaintingStyle.fill;
  final Paint _majorMarker = Paint()..style = PaintingStyle.fill;
  final Paint _hourHand = Paint()
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round;
  final Paint _minuteHand = Paint()
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final Paint _secondHand = Paint()
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  final Paint _cap = Paint()..style = PaintingStyle.fill;
  final Paint _innerCap = Paint()..style = PaintingStyle.fill;

  _DialPainter({required this.angles, required this.isNightstand}) {
    final tone = ClockTone.of(isNightstand);
    _marker.color = tone.dialTick;
    _majorMarker.color = tone.ink;
    _hourHand.color = tone.ink;
    _minuteHand.color = tone.ink;
    _secondHand.color = tone.secondHand;
    _cap.color = tone.secondHand;
    _innerCap.color = tone.dial;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Twelve markers around the perimeter, largest at the quarters.
    for (var i = 0; i < 12; i++) {
      final isMajor = i % 3 == 0;
      canvas.drawCircle(
        _polar(center, radius - 12, i / 12),
        isMajor ? 3 : 1.8,
        isMajor ? _majorMarker : _marker,
      );
    }

    canvas.drawLine(
      center,
      _polar(center, radius * 0.48, _turns(angles.hour)),
      _hourHand,
    );
    canvas.drawLine(
      center,
      _polar(center, radius * 0.72, _turns(angles.minute)),
      _minuteHand,
    );
    canvas.drawLine(
      _polar(center, -radius * 0.18, _turns(angles.second)),
      _polar(center, radius * 0.82, _turns(angles.second)),
      _secondHand,
    );

    canvas.drawCircle(center, 4, _cap);
    canvas.drawCircle(center, 1.8, _innerCap);
  }

  /// A point [distance] from [center] at [turns] around the dial, 12 o'clock up.
  static Offset _polar(Offset center, double distance, double turns) {
    final angle = turns * 2 * math.pi - math.pi / 2;
    return Offset(
      center.dx + distance * math.cos(angle),
      center.dy + distance * math.sin(angle),
    );
  }

  static double _turns(double radians) => radians / (2 * math.pi);

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.angles != angles || oldDelegate.isNightstand != isNightstand;
}
