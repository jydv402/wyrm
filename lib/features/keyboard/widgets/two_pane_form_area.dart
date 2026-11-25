import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

import '../in_app_keyboard_controller.dart';
import '../in_app_keyboard_widget.dart';

/// Content area for the two-pane editor that adapts between wide (split pane)
/// and narrow (stacked) layouts based on available width.
class TwoPaneFormArea extends StatelessWidget {
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final Widget Function(BuildContext context) previewBuilder;
  final InAppKeyboardController keyboardController;
  final VoidCallback onSave;
  final DuskTone tone;

  const TwoPaneFormArea({
    super.key,
    required this.formBuilder,
    required this.previewBuilder,
    required this.keyboardController,
    required this.onSave,
    this.tone = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14.0,
            children: [
              Expanded(
                flex: 4,
                child: TwoPaneFormCard(
                  formBuilder: formBuilder,
                  keyboardController: keyboardController,
                  tone: tone,
                ),
              ),
              Expanded(
                flex: 6,
                child: TwoPanePreviewCard(
                  previewBuilder: previewBuilder,
                  keyboardController: keyboardController,
                  onSave: onSave,
                  tone: tone,
                ),
              ),
            ],
          );
        } else {
          return TwoPaneNarrowLayout(
            formBuilder: formBuilder,
            previewBuilder: previewBuilder,
            keyboardController: keyboardController,
            onSave: onSave,
            tone: tone,
          );
        }
      },
    );
  }
}

/// Left pane card hosting the scrollable form fields in a Dusk Glass panel.
class TwoPaneFormCard extends StatelessWidget {
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final InAppKeyboardController keyboardController;
  final DuskTone tone;

  const TwoPaneFormCard({
    super.key,
    required this.formBuilder,
    required this.keyboardController,
    this.tone = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return DuskGlassPanel(
      tone: tone,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: formBuilder(context, keyboardController),
      ),
    );
  }
}

/// Right pane card hosting the WYSIWYG preview and in-app keyboard in a Dusk Glass panel.
class TwoPanePreviewCard extends StatelessWidget {
  final Widget Function(BuildContext context) previewBuilder;
  final InAppKeyboardController keyboardController;
  final VoidCallback onSave;
  final DuskTone tone;

  const TwoPanePreviewCard({
    super.key,
    required this.previewBuilder,
    required this.keyboardController,
    required this.onSave,
    this.tone = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return DuskGlassPanel(
      tone: tone,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          Expanded(child: _buildPreviewArea(context)),
          InAppKeyboardWidget(
            controller: keyboardController,
            onDonePressed: onSave,
            tone: tone,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.0,
      children: [
        Row(
          spacing: 6.0,
          children: [
            const Icon(
              Icons.visibility_rounded,
              size: 15,
              color: AppColors.textSecondary,
            ),
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
        Expanded(
          child: Center(
            child: SingleChildScrollView(child: previewBuilder(context)),
          ),
        ),
      ],
    );
  }
}

/// Narrow fallback stacking form, preview, and keyboard vertically.
class TwoPaneNarrowLayout extends StatelessWidget {
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final Widget Function(BuildContext context) previewBuilder;
  final InAppKeyboardController keyboardController;
  final VoidCallback onSave;
  final DuskTone tone;

  const TwoPaneNarrowLayout({
    super.key,
    required this.formBuilder,
    required this.previewBuilder,
    required this.keyboardController,
    required this.onSave,
    this.tone = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.0,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12.0,
              children: [
                DuskGlassPanel(
                  tone: tone,
                  borderRadius: 20.0,
                  padding: const EdgeInsets.all(16),
                  child: formBuilder(context, keyboardController),
                ),
                DuskGlassPanel(
                  tone: tone,
                  borderRadius: 20.0,
                  padding: const EdgeInsets.all(16),
                  child: previewBuilder(context),
                ),
              ],
            ),
          ),
        ),
        InAppKeyboardWidget(
          controller: keyboardController,
          onDonePressed: onSave,
          tone: tone,
        ),
      ],
    );
  }
}
