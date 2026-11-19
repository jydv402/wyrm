import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';

/// Squircle analogue dial in the Rams instrument idiom.
///
/// The dial answers one question - what time is it - with dots rather than
/// numerals, so it stays legible across the room.
///
/// In the standard tier the carriage is smoked glass: the photograph drifts
/// behind it, frosted by a backdrop blur, so the dial sits in the scene instead
/// of punching a hole in it. The nightstand tier is the opposite instrument -
/// sealed black on a dark room, no backdrop to show.
class AnalogClock extends ConsumerWidget {
  /// Outer dimension of the squircle carriage. If null, dynamically sizes to
  /// occupy available layout constraints.
  final double? size;

  /// Amber-on-black palette for the nightstand tier.
  final bool isNightstand;

  const AnalogClock({super.key, this.size, this.isNightstand = false});

  Widget _buildDial(BuildContext context, WidgetRef ref, double dimension) {
    final tone = ClockTone.of(isNightstand);
    final borderRadius = BorderRadius.circular(math.max(16.0, dimension * 0.1));
    final padding = EdgeInsets.all(math.max(12.0, dimension * 0.05));
    final dial = CustomPaint(
      painter: _DialPainter(
        angles: ref.watch(clockHandAnglesProvider),
        isNightstand: isNightstand,
      ),
    );

    // Nightstand: a sealed black instrument. No wash, no blur - in a dark room
    // the only light is the amber itself.
    if (tone.glassBlur <= 0) {
      return Container(
        width: dimension,
        height: dimension,
        padding: padding,
        decoration: BoxDecoration(
          color: tone.dial,
          borderRadius: borderRadius,
          border: Border.all(color: tone.rim, width: 1.5),
        ),
        child: dial,
      );
    }

    return SizedBox(
      width: dimension,
      height: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: clockGlassShadow,
              blurRadius: dimension * 0.06,
              spreadRadius: -dimension * 0.03,
              offset: Offset(0, dimension * 0.02),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: tone.glassBlur,
              sigmaY: tone.glassBlur,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: tone.glass,
                borderRadius: borderRadius,
                border: Border.all(color: tone.rim),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.55],
                          colors: [
                            clockGlassSheen,
                            clockGlassSheen.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: dial),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (size != null) {
      return _buildDial(context, ref, size!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDimension = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final effectiveDimension = maxDimension.isFinite && maxDimension > 0
            ? maxDimension * 0.75
            : 320.0;
        return Center(child: _buildDial(context, ref, effectiveDimension));
      },
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
    final markerInset = math.max(12.0, radius * 0.08);
    for (var i = 0; i < 12; i++) {
      final isMajor = i % 3 == 0;
      canvas.drawCircle(
        _polar(center, radius - markerInset, i / 12),
        isMajor ? 3.0 : 1.8,
        isMajor ? _majorMarker : _marker,
      );
    }

    // Dynamic hand stroke scale
    _hourHand.strokeWidth = math.max(3.5, radius * 0.032);
    _minuteHand.strokeWidth = math.max(2.5, radius * 0.022);
    _secondHand.strokeWidth = math.max(1.5, radius * 0.012);

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

    // Second hand: reaches closer to the perimeter, has a tail extending
    // past the centre cap, and carries the clock's one moving accent.
    canvas.drawLine(
      _polar(center, -radius * 0.18, _turns(angles.second)),
      _polar(center, radius * 0.82, _turns(angles.second)),
      _secondHand,
    );

    // Centre cap: small disc concealing the hand pivot.
    canvas.drawCircle(center, math.max(3.5, radius * 0.028), _cap);
    canvas.drawCircle(center, math.max(1.8, radius * 0.014), _innerCap);
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
