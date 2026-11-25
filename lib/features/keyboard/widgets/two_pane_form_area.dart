import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

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

  const TwoPaneFormArea({
    super.key,
    required this.formBuilder,
    required this.previewBuilder,
    required this.keyboardController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: TwoPaneFormCard(
                  formBuilder: formBuilder,
                  keyboardController: keyboardController,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                child: TwoPanePreviewCard(
                  previewBuilder: previewBuilder,
                  keyboardController: keyboardController,
                  onSave: onSave,
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
          );
        }
      },
    );
  }
}

/// Left pane card hosting the scrollable form fields.
class TwoPaneFormCard extends StatelessWidget {
  final Widget Function(BuildContext context, InAppKeyboardController keyboard)
  formBuilder;
  final InAppKeyboardController keyboardController;

  const TwoPaneFormCard({
    super.key,
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
class TwoPanePreviewCard extends StatelessWidget {
  final Widget Function(BuildContext context) previewBuilder;
  final InAppKeyboardController keyboardController;
  final VoidCallback onSave;

  const TwoPanePreviewCard({
    super.key,
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
          Expanded(child: _buildPreviewArea(context)),
          const SizedBox(height: 12),
          InAppKeyboardWidget(
            controller: keyboardController,
            onDonePressed: onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    return Column(
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

  const TwoPaneNarrowLayout({
    super.key,
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
