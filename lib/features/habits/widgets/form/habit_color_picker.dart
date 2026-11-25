import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Preset color options for habits.
const List<String> habitColorPresets = [
  '#A0D2B4', // Sage
  '#2DD4BF', // Teal
  '#38BDF8', // Sky Blue
  '#A78BFA', // Violet
  '#F472B6', // Pink
  '#FB923C', // Orange
  '#F87171', // Red
  '#FBBF24', // Amber
];

/// Helper to parse a hex color string.
Color parseHexColor(String hex) {
  final clean = hex.replaceAll('#', '');
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return Color(value ?? 0xFFA0D2B4);
}

/// Selector widget for choosing a habit's theme or accent color.
class HabitColorPicker extends StatelessWidget {
  final String selectedColorHex;
  final ValueChanged<String> onColorChanged;
  final VoidCallback? onChanged;

  const HabitColorPicker({
    super.key,
    required this.selectedColorHex,
    required this.onColorChanged,
    this.onChanged,
  });

  Widget _buildColorSwatch(String colorHex) {
    final isSelected = selectedColorHex.toLowerCase() == colorHex.toLowerCase();
    final color = parseHexColor(colorHex);

    return InkWell(
      onTap: () {
        onColorChanged(colorHex);
        onChanged?.call();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 2.5 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Center(
                child: Icon(Icons.check, size: 16, color: Colors.black87),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Accent Color',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: habitColorPresets.map(_buildColorSwatch).toList(),
        ),
      ],
    );
  }
}
