import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';

/// Tall left-hand container designated for the clock, date, and quick controls.
class ClockContainer extends StatelessWidget {
  /// Custom nested content or widget tree.
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
    final content = child ??
        const Text(
          '12:50 PM',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        );

    return BentoBox(
      color: AppColors.cardWhite,
      borderRadius: 32.0,
      child: onSelectSize != null
          ? Stack(
              children: [
                Center(child: content),
                CardEditButton(
                  onSelectSize: onSelectSize!,
                  currentSize: currentSize,
                  isDarkGlyph: true,
                ),
              ],
            )
          : Center(child: content),
    );
  }
}
