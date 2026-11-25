import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

import 'in_app_keyboard_controller.dart';
import 'in_app_keyboard_scope.dart';
import 'widgets/letters_keyboard_layout.dart';
import 'widgets/numpad_keyboard_layout.dart';
import 'widgets/symbols_keyboard_layout.dart';

export 'widgets/keyboard_bottom_bar.dart';
export 'widgets/keyboard_key_button.dart';
export 'widgets/letters_keyboard_layout.dart';
export 'widgets/numpad_keyboard_layout.dart';
export 'widgets/numpad_key_button.dart';
export 'widgets/symbols_keyboard_layout.dart';

/// Ergonomic, touch-first in-app virtual keyboard widget.
/// Designed for tablet form factors with tactile key styling and discrete
/// letter, symbol, and numeric keypad layouts.
class InAppKeyboardWidget extends StatelessWidget {
  final InAppKeyboardController? controller;
  final double height;
  final VoidCallback? onDonePressed;

  const InAppKeyboardWidget({
    super.key,
    this.controller,
    this.height = 236.0,
    this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveController =
        controller ?? InAppKeyboardScope.maybeOf(context);

    if (effectiveController == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: switch (effectiveController.mode) {
            VirtualKeyboardMode.letters => LettersKeyboardLayout(
              kb: effectiveController,
              onDonePressed: onDonePressed,
            ),
            VirtualKeyboardMode.symbols => SymbolsKeyboardLayout(
              kb: effectiveController,
              onDonePressed: onDonePressed,
            ),
            VirtualKeyboardMode.numpad => NumpadKeyboardLayout(
              kb: effectiveController,
              onDonePressed: onDonePressed,
            ),
          },
        );
      },
    );
  }
}
