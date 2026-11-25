import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';

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

  Widget _buildHeader(String displayTitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: buildHabitGlyph(
            iconName,
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
    );
  }

  Widget _buildGoalInfo() {
    final text = type == HabitType.numeric
        ? 'Target: $targetCount ${unit ?? "times"} / day'
        : 'Daily Check-in Goal';

    return Text(
      text,
      style: TextStyle(
        color: AppColors.textOnLight.withValues(alpha: 0.8),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildActionPreview() {
    return Container(
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
    );
  }

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
          _buildHeader(displayTitle),
          const SizedBox(height: 14),
          _buildGoalInfo(),
          const SizedBox(height: 12),
          _buildActionPreview(),
        ],
      ),
    );
  }
}
