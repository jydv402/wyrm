import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_bottom_bar.dart';
import 'keyboard_key_button.dart';

/// QWERTY letter layout with shift, caps lock, cursor nudges, and Done.
class LettersKeyboardLayout extends StatelessWidget {
  static const _row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  static const _row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;

  const LettersKeyboardLayout({
    super.key,
    required this.kb,
    this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopRow(),
        const SizedBox(height: 5),
        _buildMiddleRow(),
        const SizedBox(height: 5),
        _buildBottomRow(),
        const SizedBox(height: 5),
        KeyboardBottomBar(
          kb: kb,
          modeSwitchLabel: '?123',
          modeSwitchTarget: VirtualKeyboardMode.symbols,
          onDonePressed: onDonePressed,
        ),
      ],
    );
  }

  Widget _buildTopRow() {
    return Expanded(
      child: Row(
        children: _row1.map((char) {
          final label = kb.isShifted ? char.toUpperCase() : char;
          return Expanded(
            child: KeyButton(label: label, onTap: () => kb.insertText(char)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Expanded(
      child: Row(
        children: [
          const Spacer(flex: 1),
          ..._row2.map((char) {
            final label = kb.isShifted ? char.toUpperCase() : char;
            return Expanded(
              flex: 2,
              child: KeyButton(label: label, onTap: () => kb.insertText(char)),
            );
          }),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ActionKeyButton(
              icon: kb.isCapsLock
                  ? Icons.keyboard_capslock_rounded
                  : Icons.arrow_upward_rounded,
              isActive: kb.isShifted,
              activeColor: AppColors.accentOrange,
              onTap: kb.toggleShift,
              onLongPress: kb.toggleCapsLock,
            ),
          ),
          ..._row3.map((char) {
            final label = kb.isShifted ? char.toUpperCase() : char;
            return Expanded(
              flex: 2,
              child: KeyButton(label: label, onTap: () => kb.insertText(char)),
            );
          }),
          Expanded(
            flex: 3,
            child: ActionKeyButton(
              icon: Icons.backspace_outlined,
              onTap: kb.backspace,
              onLongPress: kb.clear,
            ),
          ),
        ],
      ),
    );
  }
}
