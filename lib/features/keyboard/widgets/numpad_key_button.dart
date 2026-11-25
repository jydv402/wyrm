import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

import '../in_app_keyboard_controller.dart';
import 'keyboard_key_button.dart';

/// A single numpad digit key button that feeds input to [InAppKeyboardController].
class NumpadKeyButton extends StatelessWidget {
  final String digit;
  final InAppKeyboardController kb;
  final DuskTone? tone;

  const NumpadKeyButton({
    super.key,
    required this.digit,
    required this.kb,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: KeyButton(
        label: digit,
        fontSize: 18,
        onTap: () => kb.insertText(digit),
        tone: tone,
      ),
    );
  }
}
