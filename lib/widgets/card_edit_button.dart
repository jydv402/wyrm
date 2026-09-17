import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';

/// Corner button that triggers an in-place pop-up menu for selecting container dimensions.
class CardEditButton extends StatelessWidget {
  /// Invoked when the user selects a size tier from the in-place menu.
  final ValueChanged<CardSize> onSelectSize;

  /// Active sizing state of the host card.
  final CardSize currentSize;

  /// Dark mode toggle for the button glyph and container based on card contrast.
  final bool isDarkGlyph;

  const CardEditButton({
    super.key,
    required this.onSelectSize,
    this.currentSize = CardSize.small,
    this.isDarkGlyph = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDarkGlyph ? Colors.black87 : Colors.white;
    final containerColor = isDarkGlyph
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.16);
    final borderColor = isDarkGlyph
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.25);

    return Positioned(
      top: 12,
      right: 12,
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: PopupMenuButton<CardSize>(
          onSelected: onSelectSize,
          tooltip: 'Select card size',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          elevation: 6,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: AppColors.borderDark,
              width: 1.0,
            ),
          ),
          itemBuilder: (context) => [
            _buildMenuItem(
              size: CardSize.small,
              label: 'Small',
              icon: Icons.crop_square_rounded,
              isSelected: currentSize == CardSize.small,
            ),
            _buildMenuItem(
              size: CardSize.medium,
              label: 'Medium',
              icon: Icons.view_column_rounded,
              isSelected: currentSize == CardSize.medium,
            ),
            _buildMenuItem(
              size: CardSize.fullscreen,
              label: 'Fullscreen',
              icon: Icons.fullscreen_rounded,
              isSelected: currentSize == CardSize.fullscreen,
            ),
          ],
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: containerColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an individual item in the in-place sizing popup menu.
  PopupMenuItem<CardSize> _buildMenuItem({
    required CardSize size,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<CardSize>(
      value: size,
      height: 42,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
                isSelected ? AppColors.accentOrange : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color:
                  isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.accentOrange,
            ),
        ],
      ),
    );
  }
}

