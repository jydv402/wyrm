import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Reusable single-line text prompt dialog for folder creation, renaming,
/// root path editing, and custom password configuration.
class SharingTextPromptDialog extends StatefulWidget {
  /// Dialog heading.
  final String title;

  /// Input field label or hint.
  final String hintText;

  /// Primary confirmation button label.
  final String confirmLabel;

  /// Initial value pre-populated in the text field.
  final String initialValue;

  /// Whether empty input is allowed (e.g. clearing a custom password).
  final bool allowEmpty;

  /// Creates a [SharingTextPromptDialog].
  const SharingTextPromptDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.initialValue = '',
    this.allowEmpty = false,
  });

  /// Prompts the user for a single string and returns `null` when cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String hintText,
    required String confirmLabel,
    String initialValue = '',
    bool allowEmpty = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => SharingTextPromptDialog(
        title: title,
        hintText: hintText,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
        allowEmpty: allowEmpty,
      ),
    );
  }

  @override
  State<SharingTextPromptDialog> createState() =>
      _SharingTextPromptDialogState();
}

class _SharingTextPromptDialogState extends State<SharingTextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (!widget.allowEmpty && trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380.0),
        child: DuskGlassPanel(
          tone: AppColors.cobalt,
          borderRadius: 24.0,
          padding: const EdgeInsetsDirectional.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14.0,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.0,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.well,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 14.0,
                    vertical: 12.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(
                      color: AppColors.cobaltAccent,
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8.0,
                children: [
                  DuskGlassButton(
                    onPressed: () => Navigator.of(context).pop(),
                    height: 36.0,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14.0,
                    ),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                  DuskGlassButton(
                    onPressed: _submit,
                    height: 36.0,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 16.0,
                    ),
                    label: Text(
                      widget.confirmLabel,
                      style: const TextStyle(
                        color: AppColors.cobaltAccent,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
