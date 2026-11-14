import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

import 'in_app_keyboard_controller.dart';
import 'in_app_keyboard_scope.dart';
import 'in_app_keyboard_widget.dart';

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
                _TwoPaneTopBar(
                  title: widget.title,
                  onSave: widget.onSave,
                  saveLabel: widget.saveLabel,
                  saveButtonColor: widget.saveButtonColor,
                  saveTextColor: widget.saveTextColor,
                  saveIcon: widget.saveIcon,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Pane: Form Fields (40% width)
                            Expanded(
                              flex: 4,
                              child: _TwoPaneFormCard(
                                formBuilder: widget.formBuilder,
                                keyboardController: _keyboardController,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Right Pane: Live Preview & In-App Keyboard (60% width)
                            Expanded(
                              flex: 6,
                              child: _TwoPanePreviewCard(
                                previewBuilder: widget.previewBuilder,
                                keyboardController: _keyboardController,
                                onSave: widget.onSave,
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Narrow fallback for compact screens
                        return _TwoPaneNarrowLayout(
                          formBuilder: widget.formBuilder,
                          previewBuilder: widget.previewBuilder,
                          keyboardController: _keyboardController,
                          onSave: widget.onSave,
                        );
                      }
                    },
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

/// Top bar with back button, editor title, Cancel, and Save actions.
class _TwoPaneTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final String saveLabel;
  final Color saveButtonColor;
  final Color saveTextColor;
  final IconData saveIcon;

  const _TwoPaneTopBar({
    required this.title,
    required this.onSave,
    required this.saveLabel,
    required this.saveButtonColor,
    required this.saveTextColor,
    required this.saveIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          splashRadius: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onSave,
          icon: Icon(saveIcon, size: 18),
          label: Text(
            saveLabel,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: saveButtonColor,
            foregroundColor: saveTextColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left pane card hosting the scrollable form fields.
class _TwoPaneFormCard extends StatelessWidget {
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final InAppKeyboardController keyboardController;

  const _TwoPaneFormCard({
    required this.formBuilder,
    required this.keyboardController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderDark, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: formBuilder(context, keyboardController),
      ),
    );
  }
}

/// Right pane card hosting the WYSIWYG preview and the in-app keyboard.
class _TwoPanePreviewCard extends StatelessWidget {
  final Widget Function(BuildContext context) previewBuilder;
  final InAppKeyboardController keyboardController;
  final VoidCallback onSave;

  const _TwoPanePreviewCard({
    required this.previewBuilder,
    required this.keyboardController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderDark, width: 1.5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Area: Live WYSIWYG Preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE PREVIEW',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: previewBuilder(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Lower Area: Touch Virtual Keyboard
          InAppKeyboardWidget(
            controller: keyboardController,
            onDonePressed: onSave,
          ),
        ],
      ),
    );
  }
}

/// Narrow fallback stacking form, preview, and keyboard vertically.
class _TwoPaneNarrowLayout extends StatelessWidget {
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final Widget Function(BuildContext context) previewBuilder;
  final InAppKeyboardController keyboardController;
  final VoidCallback onSave;

  const _TwoPaneNarrowLayout({
    required this.formBuilder,
    required this.previewBuilder,
    required this.keyboardController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: formBuilder(context, keyboardController),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: previewBuilder(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        InAppKeyboardWidget(
          controller: keyboardController,
          onDonePressed: onSave,
        ),
      ],
    );
  }
}
