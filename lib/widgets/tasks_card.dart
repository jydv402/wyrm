import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'bento_box.dart';
import 'card_edit_button.dart';

/// Safety orange bento card designated for daily task priorities.
class TasksCard extends StatelessWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback to launch the size selection dialog.
  final VoidCallback? onEdit;

  /// Whether the card is currently presented in full-screen presentation mode.
  final bool isFullScreen;

  const TasksCard({
    super.key,
    this.child,
    this.onEdit,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ??
        const Text(
          'Tasks',
          style: TextStyle(
            color: AppColors.textOnLight,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        );

    return BentoBox(
      color: AppColors.cardOrange,
      borderRadius: 28.0,
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
