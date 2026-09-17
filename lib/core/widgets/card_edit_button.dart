import 'package:flutter/material.dart';

/// Corner button allowing the user to trigger the container sizing dialog or restore full-screen views.
class CardEditButton extends StatelessWidget {
  /// Invoked when the user taps the button.
  final VoidCallback onTap;

  /// Whether the card is currently presented in full-screen mode.
  final bool isFullScreen;

  /// Dark mode toggle for the button glyph and container based on card contrast.
  final bool isDarkGlyph;

  const CardEditButton({
    super.key,
    required this.onTap,
    this.isFullScreen = false,
    this.isDarkGlyph = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDarkGlyph ? Colors.black87 : Colors.white;
    final containerColor = isDarkGlyph
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.16);
    final borderColor = isDarkGlyph
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.25);

    return Positioned(
      top: 12,
      right: 12,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: containerColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
          ),
          child: Icon(
            isFullScreen
                ? Icons.fullscreen_exit_rounded
                : Icons.tune_rounded,
            size: 16,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
