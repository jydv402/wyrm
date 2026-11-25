import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';

/// 7-day circular completion dots matching assets/web Dusk Glass .week__dot
class HabitWeekDots extends ConsumerWidget {
  final HabitItem habit;
  final DateTime weekStart;
  final DateTime today;
  final bool startWeekOnMonday;

  const HabitWeekDots({
    super.key,
    required this.habit,
    required this.weekStart,
    required this.today,
    required this.startWeekOnMonday,
  });

  void _onDayTap(WidgetRef ref, DateTime dayDate) {
    if (habit.type == HabitType.binary) {
      ref.read(habitsProvider.notifier).toggleCompletion(habit.id, dayDate);
    } else {
      ref.read(habitsProvider.notifier).stepCompletion(habit.id, 1, dayDate);
    }
  }

  Widget _buildDotIndicator({
    required bool isCompleted,
    required bool isToday,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.tealFill : AppColors.well,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted
              ? Colors.transparent
              : (isToday ? AppColors.tealAccent : AppColors.lineStrong),
          width: isToday ? 1.5 : 1.0,
        ),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: AppColors.tealFill.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: isCompleted
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.tealInk)
          : (isToday
                ? Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.tealAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null),
    );
  }

  Widget _buildDayColumn({
    required WidgetRef ref,
    required String label,
    required DateTime dayDate,
    required bool isToday,
    required bool isCompleted,
  }) {
    return InkWell(
      onTap: () => _onDayTap(ref, dayDate),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isToday ? AppColors.tealAccent : AppColors.textMuted,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            _buildDotIndicator(isCompleted: isCompleted, isToday: isToday),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayLabels = !startWeekOnMonday
        ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayDate = weekStart.add(Duration(days: index));
        final isToday =
            dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day;
        final isCompleted = habit.isCompletedOn(dayDate);

        return _buildDayColumn(
          ref: ref,
          label: dayLabels[index],
          dayDate: dayDate,
          isToday: isToday,
          isCompleted: isCompleted,
        );
      }),
    );
  }
}
