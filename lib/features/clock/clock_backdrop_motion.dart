import 'package:material_ui/material_ui.dart';

/// Pacing for the clock backdrop's slow horizontal drift.
///
/// A time-of-day photograph is scaled to the card's height, so it is always
/// wider than the card that shows it. The drift walks that spare width to the
/// far edge and back, which is how the whole panorama gets seen.
///
/// The motion is a fixed pixel [step] on a fixed [interval] rather than a
/// per-frame tween: at this pace a tween resamples the photograph for under a
/// pixel of travel, and the drift only needs to be caught in passing. Stepping
/// also means a slow frame costs one step instead of a visible jump.
@immutable
class ClockBackdropMotion {
  /// How far the photograph jumps on each tick, in logical pixels.
  final double step;

  /// Time between ticks. Must be positive.
  final Duration interval;

  /// Cross-fade used when the photograph for the current time of day changes.
  final Duration crossFade;

  const ClockBackdropMotion({
    this.step = 0.5,
    this.interval = const Duration(seconds: 1),
    this.crossFade = const Duration(seconds: 1),
  }) : assert(step > 0, 'A backdrop that never moves is a still image');

  double get speed =>
      step * Duration.microsecondsPerSecond / interval.inMicroseconds;
}

/// The clock's one tuning point: edit these values to retune the drift.
const clockBackdropMotion = ClockBackdropMotion();
