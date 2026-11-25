import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Uniform Dusk Glass card header hosting domain icon, card title, badge, and circular glass actions.
///
/// App-specific trailing controls (such as the card-size menu button) are
/// passed in through [editButton], keeping this design system widget free of
/// card layout knowledge.
class DuskCardHeader extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final Color? accentColor;
  final Widget? badge;
  final VoidCallback? onAdd;
  final Color? addColor;
  final Color? addForegroundColor;
  final Widget? editButton;
  final List<Widget>? extraActions;

  const DuskCardHeader({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.accentColor,
    this.badge,
    this.onAdd,
    this.addColor,
    this.addForegroundColor,
    this.editButton,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final domainAccent = accentColor ?? AppColors.textPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Domain Icon
        if (iconWidget != null)
          iconWidget!
        else if (icon != null)
          Icon(icon, size: 20, color: domainAccent),

        if (icon != null || iconWidget != null) const SizedBox(width: 10),

        // Title
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),

        // Optional auxiliary badge
        if (badge != null) ...[const SizedBox(width: 8), badge!],

        const Spacer(),

        // Extra action buttons (if any)
        ...?extraActions,

        // Add action button '+'
        if (onAdd != null) ...[
          const SizedBox(width: 8),
          DuskGlassButton.icon(
            onPressed: onAdd,

            isPrimary: addColor != null,
            primaryColor: addColor,
            icon: Icon(
              Icons.add_rounded,
              size: 20,
              color:
                  addForegroundColor ??
                  (addColor != null ? Colors.black : AppColors.textPrimary),
            ),
          ),
        ],

        // App-supplied trailing control (e.g. card-size menu)
        if (editButton != null) ...[const SizedBox(width: 8), editButton!],
      ],
    );
  }
}
