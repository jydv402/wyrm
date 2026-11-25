import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

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
  final DuskTone? tone;

  const InAppKeyboardWidget({
    super.key,
    this.controller,
    this.height = 236.0,
    this.onDonePressed,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveController =
        controller ?? InAppKeyboardScope.maybeOf(context);

    if (effectiveController == null) {
      return const SizedBox.shrink();
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        final currentLayout = switch (effectiveController.mode) {
          VirtualKeyboardMode.letters => LettersKeyboardLayout(
            key: const ValueKey(VirtualKeyboardMode.letters),
            kb: effectiveController,
            onDonePressed: onDonePressed,
            tone: tone,
          ),
          VirtualKeyboardMode.symbols => SymbolsKeyboardLayout(
            key: const ValueKey(VirtualKeyboardMode.symbols),
            kb: effectiveController,
            onDonePressed: onDonePressed,
            tone: tone,
          ),
          VirtualKeyboardMode.numpad => NumpadKeyboardLayout(
            key: const ValueKey(VirtualKeyboardMode.numpad),
            kb: effectiveController,
            onDonePressed: onDonePressed,
            tone: tone,
          ),
        };

        final animatedContent = AnimatedSwitcher(
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            if (disableAnimations) return child;
            return FadeTransition(opacity: animation, child: child);
          },
          child: currentLayout,
        );

        if (tone != null) {
          return DuskGlassPanel(
            tone: tone!,
            borderRadius: 18.0,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: animatedContent,
          );
        }

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
          child: animatedContent,
        );
      },
    );
  }
}
