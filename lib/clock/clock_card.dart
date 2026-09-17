import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/widgets/analog_clock.dart';
import 'package:wyrm_desk/widgets/digital_clock_medium.dart';
import 'package:wyrm_desk/widgets/digital_clock_small.dart';

/// Primary clock card container supporting Small, Medium, Fullscreen, and Nightstand sizing tiers.
///
/// Features dynamic responsive layout switching between a vertical digital clock in Small mode,
/// a horizontal digital clock in Medium mode, a dual squircle-analogue + horizontal-digital
/// companion arrangement in Fullscreen mode, and a dedicated pitch-black glowing amber Nightstand mode.
class ClockContainer extends StatelessWidget {
  /// Custom nested content or widget tree overriding the default clock view.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const ClockContainer({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context) {
    final isNightstand = currentSize == CardSize.nightstand;

    final Widget content;
    if (child != null) {
      content = child!;
    } else {
      switch (currentSize) {
        case CardSize.small:
          content = const DigitalClockSmall();
        case CardSize.medium:
          content = const DigitalClockMedium();
        case CardSize.fullscreen:
          content = const _ClockFullscreenView();
        case CardSize.nightstand:
          content = const _ClockFullscreenView(isNightstand: true);
      }
    }

    final cardColor = isNightstand ? Colors.black : AppColors.cardWhite;
    final cardBorder = isNightstand
        ? Border.all(
            color: const Color(0xFFFF9500).withValues(alpha: 0.2),
            width: 1.5,
          )
        : null;

    return BentoBox(
      color: cardColor,
      borderRadius: 32.0,
      border: cardBorder,
      child: onSelectSize != null
          ? Stack(
              children: [
                Positioned.fill(child: content),
                CardEditButton(
                  onSelectSize: onSelectSize!,
                  currentSize: currentSize,
                  isDarkGlyph: !isNightstand,
                  showNightstandOption: true,
                ),
              ],
            )
          : content,
    );
  }
}

/// Fullscreen companion view pairing a squircle analogue clock with the horizontal digital clock.
class _ClockFullscreenView extends StatelessWidget {
  final bool isNightstand;

  const _ClockFullscreenView({this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    final seamColor = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    return Row(
      children: [
        // Left side: squircle analogue clock with Dieter Rams instrument aesthetic.
        Expanded(
          flex: 5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 24.0,
                horizontal: 24.0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnalogClock(
                  size: 320,
                  isNightstand: isNightstand,
                ),
              ),
            ),
          ),
        ),

        // Subtle vertical hardware separation seam.
        Container(
          width: 1.5,
          height: 180,
          color: seamColor,
        ),

        // Right side: horizontal digital clock layout.
        Expanded(
          flex: 6,
          child: Center(
            child: DigitalClockMedium(isNightstand: isNightstand),
          ),
        ),
      ],
    );
  }
}
