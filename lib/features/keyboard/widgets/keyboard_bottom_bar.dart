import 'package:material_ui/material_ui.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_key_button.dart';

/// Shared bottom row for the letter and symbol layouts: mode switch, cursor
/// nudges, spacebar, and Done.
class KeyboardBottomBar extends StatelessWidget {
  final InAppKeyboardController kb;
  final String modeSwitchLabel;
  final VirtualKeyboardMode modeSwitchTarget;
  final VoidCallback? onDonePressed;

  const KeyboardBottomBar({
    super.key,
    required this.kb,
    required this.modeSwitchLabel,
    required this.modeSwitchTarget,
    this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ActionKeyButton(
              label: modeSwitchLabel,
              onTap: () => kb.setMode(modeSwitchTarget),
            ),
          ),
          Expanded(
            flex: 2,
            child: ActionKeyButton(
              icon: Icons.chevron_left_rounded,
              onTap: kb.moveCursorLeft,
            ),
          ),
          Expanded(
            flex: 7,
            child: KeyButton(
              label: 'space',
              isSpacebar: true,
              onTap: () => kb.insertText(' '),
            ),
          ),
          Expanded(
            flex: 2,
            child: ActionKeyButton(
              icon: Icons.chevron_right_rounded,
              onTap: kb.moveCursorRight,
            ),
          ),
          Expanded(
            flex: 4,
            child: ActionKeyButton(
              label: 'Done',
              icon: Icons.check_rounded,
              isAccent: true,
              onTap: () {
                onDonePressed?.call();
                kb.submit();
              },
            ),
          ),
        ],
      ),
    );
  }
}
