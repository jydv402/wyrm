import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';

import 'card_edit_button.dart';

/// Reusable card header widget maintaining uniform layout across dashboard containers.
///
/// Structure: Row[Card Icon, Card Name, Badge?, Spacer, Add Button?, Pop up menu button]
class CardHeader extends StatelessWidget {
  /// Icon representing the card domain (e.g. clock, habits, calendar, tasks).
  final IconData? icon;

  /// Primary label or name of the card.
  final String title;

  /// Optional auxiliary widget positioned immediately beside the title (e.g. counter badge).
  final Widget? badge;

  /// Optional callback for the circular '+' add button. If null, button is omitted.
  final VoidCallback? onAdd;

  /// Optional callback invoked when a sizing option is selected. If null, menu is omitted.
  final ValueChanged<CardSize>? onSelectSize;

  /// Current sizing tier of the parent card.
  final CardSize currentSize;

  /// Contrast mode adjusting icon and text tints for light vs. dark card surfaces.
  final bool isDarkGlyph;

  /// Enables the 4th Nightstand option in the sizing menu (for clock cards).
  final bool showNightstandOption;

  /// When active, suppresses icon, title, and badge while retaining the sizing menu.
  final bool showHeader;

  const CardHeader({
    super.key,
    this.icon,
    required this.title,
    this.badge,
    this.onAdd,
    this.onSelectSize,
    this.currentSize = CardSize.small,
    this.isDarkGlyph = true,
    this.showNightstandOption = false,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final glyphColor = isDarkGlyph ? AppColors.textOnLight : Colors.white;
    final addIconColor = glyphColor;
    final addBgColor = (isDarkGlyph ? Colors.black : Colors.white).withValues(
      alpha: 0.12,
    );

    return Row(
      children: [
        if (!showHeader) ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: glyphColor),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              color: glyphColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
        ],

        const Spacer(),

        if (!showHeader && onAdd != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: addBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, size: 16, color: addIconColor),
              ),
            ),
          ),

        if (onSelectSize != null) ...[
          if (!showHeader && onAdd != null) const SizedBox(width: 6),
          CardEditButton(
            onSelectSize: onSelectSize!,
            currentSize: currentSize,
            isDarkGlyph: isDarkGlyph,
            showNightstandOption: showNightstandOption,
          ),
        ],
      ],
    );
  }
}
