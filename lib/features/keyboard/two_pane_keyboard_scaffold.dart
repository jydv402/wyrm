import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

import 'in_app_keyboard_controller.dart';
import 'in_app_keyboard_scope.dart';
import 'widgets/two_pane_form_area.dart';
import 'widgets/two_pane_header.dart';

export 'widgets/two_pane_form_area.dart';
export 'widgets/two_pane_header.dart';

/// Fullscreen two-pane scaffold displaying form inputs on the left card (40% width)
/// and a real-time WYSIWYG live preview plus virtual touch keyboard on the right card (60% width).
class TwoPaneKeyboardScaffold extends StatefulWidget {
  final String title;
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final Widget Function(BuildContext context) previewBuilder;
  final VoidCallback onSave;
  final String saveLabel;
  final Color saveButtonColor;
  final Color saveTextColor;
  final IconData saveIcon;

  const TwoPaneKeyboardScaffold({
    super.key,
    required this.title,
    required this.formBuilder,
    required this.previewBuilder,
    required this.onSave,
    this.saveLabel = 'Save',
    this.saveButtonColor = AppColors.cardSage,
    this.saveTextColor = AppColors.textOnLight,
    this.saveIcon = Icons.check_rounded,
  });

  @override
  State<TwoPaneKeyboardScaffold> createState() =>
      _TwoPaneKeyboardScaffoldState();
}

class _TwoPaneKeyboardScaffoldState extends State<TwoPaneKeyboardScaffold> {
  late final InAppKeyboardController _keyboardController;

  @override
  void initState() {
    super.initState();
    _keyboardController = InAppKeyboardController()
      ..onActionPressed = widget.onSave;
  }

  @override
  void dispose() {
    _keyboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppKeyboardScope(
      controller: _keyboardController,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TwoPaneHeader(
                  title: widget.title,
                  onSave: widget.onSave,
                  saveLabel: widget.saveLabel,
                  saveButtonColor: widget.saveButtonColor,
                  saveTextColor: widget.saveTextColor,
                  saveIcon: widget.saveIcon,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TwoPaneFormArea(
                    formBuilder: widget.formBuilder,
                    previewBuilder: widget.previewBuilder,
                    keyboardController: _keyboardController,
                    onSave: widget.onSave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
