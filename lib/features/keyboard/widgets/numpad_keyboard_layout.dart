import 'package:material_ui/material_ui.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_key_button.dart';
import 'numpad_key_button.dart';

/// Numeric keypad layout with backspace, mode switch, Clear, and Done.
class NumpadKeyboardLayout extends StatelessWidget {
  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;

  const NumpadKeyboardLayout({super.key, required this.kb, this.onDonePressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow123(),
        const SizedBox(height: 5),
        _buildRow456(),
        const SizedBox(height: 5),
        _buildRow789(),
        const SizedBox(height: 5),
        _buildRow0Done(),
      ],
    );
  }

  Widget _buildRow123() {
    return Expanded(
      child: Row(
        children: [
          NumpadKeyButton(digit: '1', kb: kb),
          NumpadKeyButton(digit: '2', kb: kb),
          NumpadKeyButton(digit: '3', kb: kb),
          Expanded(
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

  Widget _buildRow456() {
    return Expanded(
      child: Row(
        children: [
          NumpadKeyButton(digit: '4', kb: kb),
          NumpadKeyButton(digit: '5', kb: kb),
          NumpadKeyButton(digit: '6', kb: kb),
          Expanded(
            child: ActionKeyButton(
              label: 'ABC',
              onTap: () => kb.setMode(VirtualKeyboardMode.letters),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow789() {
    return Expanded(
      child: Row(
        children: [
          NumpadKeyButton(digit: '7', kb: kb),
          NumpadKeyButton(digit: '8', kb: kb),
          NumpadKeyButton(digit: '9', kb: kb),
          Expanded(
            child: ActionKeyButton(label: 'Clear', onTap: kb.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildRow0Done() {
    return Expanded(
      child: Row(
        children: [
          const Spacer(),
          NumpadKeyButton(digit: '0', kb: kb),
          const Spacer(),
          Expanded(
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
