import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';
import 'package:wyrm_desk/features/habits/widgets/habit_heatmap.dart';
import 'package:wyrm_desk/features/habits/widgets/habit_week_dots.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// One habit tile in the expanded grid: header row, week dots, and monthly heatmap.
class HabitGridTile extends ConsumerWidget {
  final HabitItem habit;
  final DateTime today;
  final DateTime weekStart;
  final bool startWeekOnMonday;
  final void Function(HabitItem habit)? onEdit;

  const HabitGridTile({
    super.key,
    required this.habit,
    required this.today,
    required this.weekStart,
    required this.startWeekOnMonday,
    this.onEdit,
  });

  Widget _buildHeaderRow(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.tealAccent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.tealAccent.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: buildHabitGlyph(
            habit.iconName,
            size: 22,
            color: AppColors.tealAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${habit.completionCountOn(today)} of ${habit.targetValue} completed today',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        DuskGlassButton.icon(
          onPressed: () => onEdit?.call(habit),
          size: 34,
          icon: const Icon(
            Icons.edit_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        DuskGlassButton.icon(
          onPressed: () =>
              ref.read(habitsProvider.notifier).deleteHabit(habit.id),
          size: 34,
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: AppColors.accentRed,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoneToday = habit.isCompletedOn(today);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDoneToday
              ? AppColors.tealAccent.withValues(alpha: 0.5)
              : AppColors.line,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(context, ref),
          const SizedBox(height: 8),
          HabitWeekDots(
            habit: habit,
            weekStart: weekStart,
            today: today,
            startWeekOnMonday: startWeekOnMonday,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: HabitHeatmap(
              habit: habit,
              today: today,
              startWeekOnMonday: startWeekOnMonday,
            ),
          ),
        ],
      ),
    );
  }
}
