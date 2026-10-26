import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/widgets/card_edit_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Uniform Dusk Glass card header hosting domain icon, card title, badge, and circular glass actions.
class DuskCardHeader extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final Color? accentColor;
  final Widget? badge;
  final VoidCallback? onAdd;
  final Color? addColor;
  final Color? addForegroundColor;
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;
  final bool showNightstandOption;
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
    this.onSelectSize,
    this.currentSize = CardSize.small,
    this.showNightstandOption = false,
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
          Icon(
            icon,
            size: 20,
            color: domainAccent,
          ),

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
        if (badge != null) ...[
          const SizedBox(width: 10),
          badge!,
        ],

        const Spacer(),

        // Extra action buttons (if any)
        ...?extraActions,

        // Add action button '+'
        if (onAdd != null) ...[
          const SizedBox(width: 8),
          DuskGlassButton.icon(
            onPressed: onAdd,
            size: 36.0,
            isPrimary: addColor != null,
            primaryColor: addColor,
            icon: Icon(
              Icons.add_rounded,
              size: 20,
              color: addForegroundColor ?? (addColor != null ? Colors.black : AppColors.textPrimary),
            ),
          ),
        ],

        // Sizing slider/filter button
        if (onSelectSize != null) ...[
          const SizedBox(width: 8),
          CardEditButton(
            onSelectSize: onSelectSize!,
            currentSize: currentSize,
            showNightstandOption: showNightstandOption,
          ),
        ],
      ],
    );
  }
}
