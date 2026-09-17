import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';

/// Safety orange bento card designated for daily task priorities.
class TasksCard extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const TasksCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context) {
    return BentoBox(
      color: AppColors.cardOrange,
      borderRadius: 28.0,
      child: Stack(
        children: [
          Center(
            child:
                child ??
                const Text(
                  'Tasks',
                  style: TextStyle(
                    color: AppColors.textOnLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
          ),
          if (onSelectSize != null)
            CardEditButton(
              onSelectSize: onSelectSize!,
              currentSize: currentSize,
              isDarkGlyph: true,
            ),
        ],
      ),
    );
  }
}
