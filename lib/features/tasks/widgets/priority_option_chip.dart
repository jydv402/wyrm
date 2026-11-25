import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// One selectable priority pill in the task form.
class PriorityOptionChip extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;
  final String selectedValue;
  final ValueChanged<String> onPriorityChanged;
  final VoidCallback? onChanged;

  const PriorityOptionChip({
    super.key,
    required this.value,
    required this.label,
    required this.accentColor,
    required this.selectedValue,
    required this.onPriorityChanged,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          onPriorityChanged(value);
          onChanged?.call();
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.2)
                : AppColors.well,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.line,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
