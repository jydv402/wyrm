import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

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
  final DuskTone? tone;

  const SymbolsKeyboardLayout({
    super.key,
    required this.kb,
    this.onDonePressed,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 5.0,
      children: [
        _buildCharRow(_row1),
        _buildCharRow(_row2),
        _buildBottomSymbolsRow(),
        KeyboardBottomBar(
          kb: kb,
          modeSwitchLabel: 'ABC',
          modeSwitchTarget: VirtualKeyboardMode.letters,
          onDonePressed: onDonePressed,
          tone: tone,
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
                child: KeyButton(
                  label: char,
                  tone: tone,
                  onTap: () => kb.insertText(char),
                ),
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
              child: KeyButton(
                label: char,
                tone: tone,
                onTap: () => kb.insertText(char),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ActionKeyButton(
              icon: Icons.backspace_outlined,
              tone: tone,
              onTap: kb.backspace,
              onLongPress: kb.clear,
            ),
          ),
        ],
      ),
    );
  }
}
