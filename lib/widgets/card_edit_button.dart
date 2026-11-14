import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// One selectable entry in a [CardEditButton] popup menu.
class EditMenuOption<T> {
  /// Value reported through the button's callback when this entry is picked.
  final T value;

  /// Visible entry label.
  final String label;

  /// Leading icon for the entry.
  final IconData icon;

  const EditMenuOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// Corner button that opens an in-place pop-up menu for selecting an option
/// (typically a card size) with Dusk Glass styling.
///
/// The button is generic: callers supply the option list, so this design
/// system widget knows nothing about card layout state.
class CardEditButton<T> extends StatelessWidget {
  /// Menu entries, in display order.
  final List<EditMenuOption<T>> options;

  /// Currently selected value, highlighted in the menu.
  final T currentValue;

  /// Invoked when the user selects an entry from the menu.
  final ValueChanged<T> onSelected;

  const CardEditButton({
    super.key,
    required this.options,
    required this.currentValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      tooltip: 'Select card size',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      elevation: 16,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
      ),
      itemBuilder: (context) => options
          .map(
            (option) => _buildMenuItem(
              option: option,
              isSelected: option.value == currentValue,
            ),
          )
          .toList(),
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

  PopupMenuItem<T> _buildMenuItem({
    required EditMenuOption<T> option,
    required bool isSelected,
  }) {
    return PopupMenuItem<T>(
      value: option.value,
      height: 44,
      child: Row(
        children: [
          Icon(
            option.icon,
            size: 18,
            color: isSelected
                ? AppColors.accentOrange
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            option.label,
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
