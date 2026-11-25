import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_key_button.dart';
import 'numpad_key_button.dart';

/// Numeric keypad layout with backspace, mode switch, Clear, and Done.
class NumpadKeyboardLayout extends StatelessWidget {
  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;
  final DuskTone? tone;

  const NumpadKeyboardLayout({
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
        _buildRow123(),
        _buildRow456(),
        _buildRow789(),
        _buildRow0Done(),
      ],
    );
  }

  Widget _buildRow123() {
    return Expanded(
      child: Row(
        children: [
          NumpadKeyButton(digit: '1', kb: kb, tone: tone),
          NumpadKeyButton(digit: '2', kb: kb, tone: tone),
          NumpadKeyButton(digit: '3', kb: kb, tone: tone),
          Expanded(
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

  Widget _buildRow456() {
    return Expanded(
      child: Row(
        children: [
          NumpadKeyButton(digit: '4', kb: kb, tone: tone),
          NumpadKeyButton(digit: '5', kb: kb, tone: tone),
          NumpadKeyButton(digit: '6', kb: kb, tone: tone),
          Expanded(
            child: ActionKeyButton(
              label: 'ABC',
              tone: tone,
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
          NumpadKeyButton(digit: '7', kb: kb, tone: tone),
          NumpadKeyButton(digit: '8', kb: kb, tone: tone),
          NumpadKeyButton(digit: '9', kb: kb, tone: tone),
          Expanded(
            child: ActionKeyButton(label: 'Clear', tone: tone, onTap: kb.clear),
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
          NumpadKeyButton(digit: '0', kb: kb, tone: tone),
          const Spacer(),
          Expanded(
            child: ActionKeyButton(
              label: 'Done',
              icon: Icons.check_rounded,
              isAccent: true,
              tone: tone,
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
