import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Nightstand amber: the only colour on the pitch-black tier.
const Color _amber = Color(0xFFFF9500);

/// Legibility scrim painted over the day's photograph, top to bottom.
const List<Color> clockBackdropScrim = [
  Color(0x73000000), // black 45%
  Color(0x40000000), // black 25%
  Color(0xB3000000), // black 70%
];

/// The clock's colours, for the two tiers it renders in.
///
/// The standard tier sits on slate glass and takes its ink from [AppColors];
/// the nightstand tier is pitch black carrying a single amber signal. Keeping
/// both here means a face never writes a colour literal of its own, and the
/// amber exists exactly once.
@immutable
class ClockTone {
  /// Numerals, hands, the time itself.
  final Color ink;

  /// Supporting ink: the date, the seconds, the period.
  final Color inkSecondary;

  /// Quiet ink: the colon and other separators.
  final Color inkMuted;

  /// Dial and carriage surface behind the hands.
  final Color dial;

  /// Dial rim, one step brighter than [hairline].
  final Color rim;

  /// 1 px rules: the face divider and the fullscreen seam.
  final Color hairline;

  /// Small hour markers around the dial.
  final Color dialTick;

  /// Second hand and centre cap - the one moving accent.
  final Color secondHand;

  /// AM/PM period label, matching the card's tone accent.
  final Color accent;

  const ClockTone({
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.dial,
    required this.rim,
    required this.hairline,
    required this.dialTick,
    required this.secondHand,
    required this.accent,
  });

  /// Standard slate glass tier.
  static const ClockTone standard = ClockTone(
    ink: AppColors.textPrimary,
    inkSecondary: AppColors.textSecondary,
    inkMuted: Color(0x45E8EEEE), // text secondary at 40%
    dial: AppColors.surface,
    rim: AppColors.borderDark,
    hairline: AppColors.lineStrong,
    dialTick: Color(0x80E8EEEE), // text secondary at 50%
    secondHand: AppColors.accentOrange,
    accent: AppColors.slateAccent,
  );

  /// Pitch-black nightstand tier: one amber signal, nothing else.
  static const ClockTone nightstand = ClockTone(
    ink: _amber,
    inkSecondary: Color(0xB3FF9500), // amber 70%
    inkMuted: Color(0x66FF9500), // amber 40%
    dial: Colors.black,
    rim: Color(0x40FF9500), // amber 25%
    hairline: Color(0x2EFF9500), // amber 18%
    dialTick: Color(0x66FF9500), // amber 40%
    secondHand: _amber,
    accent: _amber,
  );

  /// Resolves the tone for [nightstand].
  static ClockTone of(bool nightstand) =>
      nightstand ? ClockTone.nightstand : ClockTone.standard;
}
