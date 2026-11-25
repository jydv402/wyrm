import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Top bar with back button, editor title, Cancel, and Save actions.
class TwoPaneHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSave;
  final String saveLabel;
  final Color saveButtonColor;
  final Color saveTextColor;
  final IconData saveIcon;
  final DuskTone? tone;

  const TwoPaneHeader({
    super.key,
    required this.title,
    required this.onSave,
    required this.saveLabel,
    required this.saveButtonColor,
    required this.saveTextColor,
    required this.saveIcon,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DuskGlassButton.icon(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 12),
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
        DuskGlassButton(
          onPressed: () => context.pop(),
          label: const Text('Cancel'),
          height: 40.0,
        ),
        const SizedBox(width: 10),
        DuskGlassButton(
          onPressed: onSave,
          isPrimary: true,
          primaryColor: tone?.fill ?? saveButtonColor,
          primaryForegroundColor: saveTextColor,
          icon: Icon(saveIcon, size: 18, color: saveTextColor),
          label: Text(
            saveLabel,
            style: TextStyle(fontWeight: FontWeight.w700, color: saveTextColor),
          ),
          height: 40.0,
        ),
      ],
    );
  }
}
