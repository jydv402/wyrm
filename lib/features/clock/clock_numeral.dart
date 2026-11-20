import 'package:material_ui/material_ui.dart';

/// The clock's display type, specified once.
///
/// Every numeral on the card - hours, minutes, the colon - comes from here, so
/// the faces cannot drift apart in family, weight or tracking. Tabular figures
/// stop the digits from shifting as the seconds tick.
abstract final class ClockNumeral {
  /// Condensed instrument numeral at [size], for the time itself.
  static TextStyle display(double size, Color color) => TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w600,
    height: 0.88,
    letterSpacing: -2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Fixed-width meta digits, for the seconds and the period column.
  static TextStyle meta(double size, Color color) => TextStyle(
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w500,
    fontFamily: 'GoogleSans',
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
