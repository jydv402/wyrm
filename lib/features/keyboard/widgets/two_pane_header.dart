import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Top bar with back button, editor title, Cancel, and Save actions.
class TwoPaneHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final String saveLabel;
  final Color saveButtonColor;
  final Color saveTextColor;
  final IconData saveIcon;

  const TwoPaneHeader({
    super.key,
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
