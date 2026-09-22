import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/habits/habit_model.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard_text_field.dart';

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

/// Resolves an IconData glyph from an iconName token string.
IconData resolveHabitIcon(String? name) {
  switch (name) {
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
    case 'bolt':
    default:
      return Icons.bolt_rounded;
  }
}

/// Reusable, adaptive form content for creating and editing habits.
class HabitFormContent extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController unitController;
  final HabitType habitType;
  final int targetCount;
  final String selectedIcon;
  final ValueChanged<HabitType> onTypeChanged;
  final ValueChanged<int> onTargetCountChanged;
  final ValueChanged<String> onIconChanged;
  final VoidCallback? onChanged;
  final bool isEditing;

  const HabitFormContent({
    super.key,
    required this.titleController,
    required this.unitController,
    required this.habitType,
    required this.targetCount,
    required this.selectedIcon,
    required this.onTypeChanged,
    required this.onTargetCountChanged,
    required this.onIconChanged,
    this.onChanged,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Habit Title',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        InAppKeyboardTextField(
          controller: titleController,
          autofocus: !isEditing,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Morning Jog, Drink Water, Read',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 18),

        const Text(
          'Goal Type',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  onTypeChanged(HabitType.binary);
                  onTargetCountChanged(1);
                  onChanged?.call();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: habitType == HabitType.binary
                        ? AppColors.cardSage
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Check-in (Done/Not Done)',
                    style: TextStyle(
                      color: habitType == HabitType.binary
                          ? AppColors.textOnLight
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () {
                  onTypeChanged(HabitType.numeric);
                  if (targetCount <= 1) onTargetCountChanged(8);
                  onChanged?.call();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: habitType == HabitType.numeric
                        ? AppColors.cardSage
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Target Count (e.g. 8 cups)',
                    style: TextStyle(
                      color: habitType == HabitType.numeric
                          ? AppColors.textOnLight
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (habitType == HabitType.numeric) ...[
          const Text(
            'Daily Target & Unit',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  if (targetCount > 1) {
                    onTargetCountChanged(targetCount - 1);
                    onChanged?.call();
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$targetCount',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  onTargetCountChanged(targetCount + 1);
                  onChanged?.call();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InAppKeyboardTextField(
                  controller: unitController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Unit (e.g. cups, mins)',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => onChanged?.call(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],

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
          children: habitGlyphKeys.map((iconKey) {
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
                  resolveHabitIcon(iconKey),
                  size: 18,
                  color:
                      isSelected ? AppColors.textOnLight : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// WYSIWYG live preview tile matching the habit card style on the dashboard.
class HabitPreviewTile extends StatelessWidget {
  final String title;
  final HabitType type;
  final int targetCount;
  final String? unit;
  final String iconName;

  const HabitPreviewTile({
    super.key,
    required this.title,
    required this.type,
    required this.targetCount,
    this.unit,
    required this.iconName,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.trim().isEmpty ? 'Habit Name' : title.trim();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSage,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  resolveHabitIcon(iconName),
                  size: 20,
                  color: AppColors.textOnLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayTitle,
                  style: const TextStyle(
                    color: AppColors.textOnLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '🔥 0d',
                  style: TextStyle(
                    color: AppColors.textOnLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (type == HabitType.numeric)
            Row(
              children: [
                Text(
                  'Target: $targetCount ${unit ?? "times"} / day',
                  style: TextStyle(
                    color: AppColors.textOnLight.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  'Daily Check-in Goal',
                  style: TextStyle(
                    color: AppColors.textOnLight.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: AppColors.textOnLight,
                ),
                const SizedBox(width: 6),
                Text(
                  type == HabitType.numeric ? '0 / $targetCount' : 'Mark Done',
                  style: const TextStyle(
                    color: AppColors.textOnLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
