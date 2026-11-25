import 'package:material_ui/material_ui.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_key_button.dart';

/// A single numpad digit key button that feeds input to [InAppKeyboardController].
class NumpadKeyButton extends StatelessWidget {
  final String digit;
  final InAppKeyboardController kb;

  const NumpadKeyButton({super.key, required this.digit, required this.kb});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: KeyButton(
        label: digit,
        fontSize: 18,
        onTap: () => kb.insertText(digit),
      ),
    );
  }
}
