import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Available habit glyph identifier tokens.
const List<String> habitGlyphKeys = [
  'bolt',
  'water_drop',
  'fitness_center',
  'menu_book',
  'directions_run',
  'bedtime',
  'wb_sunny',
  'code',
  'local_cafe',
  'check_circle',
  'favorite',
];

/// Bidirectional emoji and token mapping dictionaries.
const Map<String, String> emojiToHabitIcon = {
  '💧': 'water_drop',
  '📖': 'menu_book',
  '🏋️': 'fitness_center',
  '🏋': 'fitness_center',
  '❤️': 'favorite',
  '❤': 'favorite',
  '⚡': 'bolt',
  '🔥': 'bolt',
  '💻': 'code',
  '☀️': 'wb_sunny',
  '☀': 'wb_sunny',
  '🌙': 'bedtime',
  '🎯': 'check_circle',
  '🌿': 'spa',
  '☕': 'local_cafe',
  '🏃': 'directions_run',
};

const Map<String, String> habitIconToEmoji = {
  'water_drop': '💧',
  'menu_book': '📖',
  'fitness_center': '🏋️',
  'favorite': '❤️',
  'bolt': '⚡',
  'code': '💻',
  'wb_sunny': '☀️',
  'bedtime': '🌙',
  'check_circle': '🎯',
  'spa': '🌿',
  'local_cafe': '☕',
  'directions_run': '🏃',
};

/// Resolves an IconData glyph from an iconName token string or preset emoji.
/// Returns null if the name represents an unmapped custom emoji/character.
IconData? resolveHabitIcon(String? name) {
  if (name == null || name.isEmpty) return Icons.bolt_rounded;
  final mapped = emojiToHabitIcon[name] ?? name;
  switch (mapped) {
    case 'water_drop':
      return Icons.water_drop_rounded;
    case 'fitness_center':
      return Icons.fitness_center_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'directions_run':
      return Icons.directions_run_rounded;
    case 'bedtime':
      return Icons.bedtime_rounded;
    case 'wb_sunny':
      return Icons.wb_sunny_rounded;
    case 'code':
      return Icons.code_rounded;
    case 'local_cafe':
      return Icons.local_cafe_rounded;
    case 'check_circle':
      return Icons.check_circle_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'spa':
      return Icons.spa_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    default:
      return null;
  }
}

/// Renders a habit glyph as a vector Material Icon or native Text emoji.
Widget buildHabitGlyph(String? iconName, {required double size, Color? color}) {
  final iconData = resolveHabitIcon(iconName);
  if (iconData != null) {
    return Icon(iconData, size: size, color: color);
  }
  return Text(
    iconName ?? '⚡',
    style: TextStyle(fontSize: size * 0.9, height: 1.0),
    textAlign: TextAlign.center,
  );
}

/// Selector widget for habit icon glyphs.
class HabitIconPicker extends StatelessWidget {
  final String selectedIcon;
  final ValueChanged<String> onIconChanged;
  final VoidCallback? onChanged;

  const HabitIconPicker({
    super.key,
    required this.selectedIcon,
    required this.onIconChanged,
    this.onChanged,
  });

  Widget _buildIconTile(String iconKey) {
    final isSelected = selectedIcon == iconKey;
    return InkWell(
      onTap: () {
        onIconChanged(iconKey);
        onChanged?.call();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cardSage
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          resolveHabitIcon(iconKey) ?? Icons.bolt_rounded,
          size: 18,
          color: isSelected ? AppColors.textOnLight : AppColors.textPrimary,
        ),
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
          'Choose Glyph',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: habitGlyphKeys.map(_buildIconTile).toList(),
        ),
      ],
    );
  }
}
