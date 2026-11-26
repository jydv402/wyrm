import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_form_section.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Reminder title input with inline validation message.
class ReminderTitleField extends StatelessWidget {
  /// Controller owned by the editor screen.
  final TextEditingController controller;

  /// Whether the field grabs focus when the editor opens (new reminders only).
  final bool autofocus;

  /// Whether to show the required-title validation message.
  final bool showError;

  /// Notifies the editor that the text changed.
  final VoidCallback? onChanged;

  /// Invoked when the keyboard submits the field.
  final ValueChanged<String>? onSubmitted;

  const ReminderTitleField({
    super.key,
    required this.controller,
    required this.autofocus,
    required this.showError,
    this.onChanged,
    this.onSubmitted,
  });

  static const _baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14.0)),
    borderSide: BorderSide(color: AppColors.line, width: 1.0),
  );

  @override
  Widget build(BuildContext context) {
    return ReminderFormSection(
      label: 'Reminder Title',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8.0,
        children: [
          InAppKeyboardTextField(
            controller: controller,
            autofocus: autofocus,
            cursorColor: AppColors.plumAccent,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.0,
            ),
            decoration: const InputDecoration(
              hintText: 'e.g. Take meds, Stretch break, Laundry',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.well,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 12.0,
              ),
              border: _baseBorder,
              enabledBorder: _baseBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14.0)),
                borderSide: BorderSide(color: AppColors.plumAccent, width: 1.5),
              ),
            ),
            onChanged: (_) => onChanged?.call(),
            onSubmitted: onSubmitted,
          ),
          if (showError)
            const Text(
              'Enter a title for this reminder.',
              style: TextStyle(
                color: AppColors.accentRed,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
