import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Bottom action buttons (CANCEL and confirm) for DuskDatePickerDialog.
class DatePickerActions extends StatelessWidget {
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const DatePickerActions({
    super.key,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildButton(
          label: cancelText.toUpperCase(),
          onTap: onCancel,
          textColor: AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        _buildButton(
          label: confirmText.toUpperCase(),
          onTap: onConfirm,
          textColor: AppColors.goldInk,
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    required Color textColor,
    bool isPrimary = false,
  }) {
    return DuskGlassButton(
      onPressed: onTap,
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: isPrimary ? 20 : 16),
      isPrimary: isPrimary,
      primaryColor: isPrimary ? AppColors.goldFill : null,
      primaryForegroundColor: isPrimary ? textColor : null,
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: isPrimary ? 0.5 : null,
        ),
      ),
    );
  }
}
