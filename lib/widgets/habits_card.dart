import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'bento_box.dart';
import 'card_edit_button.dart';

/// Sage green bento card from the top-center of the reference design.
class HabitsCard extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback to launch the size selection dialog.
  final VoidCallback? onEdit;

  /// Whether the card is currently presented in full-screen presentation mode.
  final bool isFullScreen;

  const HabitsCard({
    super.key,
    this.child,
    this.onEdit,
    this.isFullScreen = false,
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
