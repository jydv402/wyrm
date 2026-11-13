import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';

/// Corner button that triggers an in-place pop-up menu for selecting container dimensions
/// with Dusk Glass styling.
class CardEditButton extends StatelessWidget {
  /// Invoked when the user selects a size tier from the in-place menu.
  final ValueChanged<CardSize> onSelectSize;

  /// Active sizing state of the host card.
  final CardSize currentSize;

  /// Dark mode toggle for the button glyph and container based on card contrast.
  final bool isDarkGlyph;

  /// Enables the 4th Nightstand mode option for dedicated clock cards.
  final bool showNightstandOption;

  const CardEditButton({
    super.key,
    required this.onSelectSize,
    this.currentSize = CardSize.small,
    this.isDarkGlyph = true,
    this.showNightstandOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CardSize>(
      onSelected: onSelectSize,
      tooltip: 'Select card size',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      elevation: 16,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
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
        if (showNightstandOption)
          _buildMenuItem(
            size: CardSize.nightstand,
            label: 'Nightstand',
            icon: Icons.bedtime_rounded,
            isSelected: currentSize == CardSize.nightstand,
          ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.glass,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lineStrong, width: 1.0),
        ),
        child: const Icon(
          Icons.tune_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  PopupMenuItem<CardSize> _buildMenuItem({
    required CardSize size,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<CardSize>(
      value: size,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? AppColors.accentOrange
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.accentOrange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
