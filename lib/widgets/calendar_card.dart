import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'bento_box.dart';
import 'card_edit_button.dart';

/// Golden yellow main bento card from the bottom-center of the reference design.
class CalendarCard extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback to launch the size selection dialog.
  final VoidCallback? onEdit;

  /// Whether the card is currently presented in full-screen presentation mode.
  final bool isFullScreen;

  const CalendarCard({
    super.key,
    this.child,
    this.onEdit,
    this.isFullScreen = false,
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
      child: onEdit != null
          ? Stack(
              children: [
                Center(child: content),
                CardEditButton(
                  onTap: onEdit!,
                  isFullScreen: isFullScreen,
                  isDarkGlyph: true,
                ),
              ],
            )
          : Center(child: content),
    );
  }
}
