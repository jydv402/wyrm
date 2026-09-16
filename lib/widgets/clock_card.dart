import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'bento_box.dart';
import 'card_edit_button.dart';

/// Tall left-hand container designated for the clock, date, and quick controls.
class ClockContainer extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback to launch the size selection dialog.
  final VoidCallback? onEdit;

  /// Whether the card is currently presented in full-screen presentation mode.
  final bool isFullScreen;

  const ClockContainer({
    super.key,
    this.child,
    this.onEdit,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return BentoBox(
      color: AppColors.cardWhite,
      borderRadius: 32.0,
      child: Stack(
        children: [
          Center(
            child: child ??
                const Text(
                  '12:50 PM',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
          ),
          if (onEdit != null)
            CardEditButton(
              onTap: onEdit!,
              isFullScreen: isFullScreen,
              isDarkGlyph: true,
            ),
        ],
      ),
    );
  }
}
