import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';

/// Sage green bento card designated for habit tracking.
class HabitsCard extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const HabitsCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ??
        const Text(
          'Habits',
          style: TextStyle(
            color: AppColors.textOnLight,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        );

    return BentoBox(
      color: AppColors.cardSage,
      borderRadius: 30.0,
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
