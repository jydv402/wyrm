import 'package:material_ui/material_ui.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_bottom_bar.dart';
import 'keyboard_key_button.dart';

/// Symbol and punctuation layout with backspace, cursor nudges, and Done.
class SymbolsKeyboardLayout extends StatelessWidget {
  static const _row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const _row2 = ['-', '/', ':', ';', '(', ')', '\$', '&', '@', '"'];
  static const _row3 = ['.', ',', '?', '!', '\'', '%', '*', '+', '='];

  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;

  const SymbolsKeyboardLayout({
    super.key,
    required this.kb,
    this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCharRow(_row1),
        const SizedBox(height: 5),
        _buildCharRow(_row2),
        const SizedBox(height: 5),
        _buildBottomSymbolsRow(),
        const SizedBox(height: 5),
        KeyboardBottomBar(
          kb: kb,
          modeSwitchLabel: 'ABC',
          modeSwitchTarget: VirtualKeyboardMode.letters,
          onDonePressed: onDonePressed,
        ),
      ],
    );
  }

  Widget _buildCharRow(List<String> chars) {
    return Expanded(
      child: Row(
        children: chars
            .map(
              (char) => Expanded(
                child: KeyButton(label: char, onTap: () => kb.insertText(char)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBottomSymbolsRow() {
    return Expanded(
      child: Row(
        children: [
          ..._row3.map(
            (char) => Expanded(
              flex: 2,
              child: KeyButton(label: char, onTap: () => kb.insertText(char)),
            ),
          ),
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
