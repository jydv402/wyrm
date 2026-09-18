import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';

/// Golden yellow main bento card designated for calendar and agenda items.
class CalendarCard extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const CalendarCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ??
        const Text(
          'Calendar',
          style: TextStyle(
            color: AppColors.textOnLight,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        );

    return BentoBox(
      color: AppColors.cardYellow,
      borderRadius: 30.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.calendar_today_rounded,
            title: 'Calendar',
            onSelectSize: onSelectSize,
            currentSize: currentSize,
            isDarkGlyph: true,
          ),
          const SizedBox(height: 10),
          Expanded(child: Center(child: content)),
        ],
      ),
    );
  }
}
