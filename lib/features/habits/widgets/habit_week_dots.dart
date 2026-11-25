import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';

/// 7-day rectangular pill completion matrix representing the current week.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayLabels = !startWeekOnMonday
        ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: List.generate(7, (index) {
        final dayDate = weekStart.add(Duration(days: index));
        final isToday =
            dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day;
        final isCompleted = habit.isCompletedOn(dayDate);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: HabitDayPill(
              label: dayLabels[index],
              isCompleted: isCompleted,
              isToday: isToday,
              onTap: () => _onDayTap(ref, dayDate),
            ),
          ),
        );
      }),
    );
  }
}

/// A single rectangular day pill with the day letter represented inside.
class HabitDayPill extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isToday;
  final VoidCallback onTap;

  const HabitDayPill({
    super.key,
    required this.label,
    required this.isCompleted,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.tealFill : AppColors.glass,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCompleted
                ? AppColors.tealAccent
                : (isToday ? AppColors.tealAccent : AppColors.line),
            width: isToday ? 1.5 : 1.0,
          ),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: AppColors.tealFill.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCompleted)
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.tealInk,
              )
            else if (isToday)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  color: AppColors.tealAccent,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isCompleted
                    ? AppColors.tealInk
                    : (isToday ? AppColors.tealAccent : AppColors.textMuted),
                fontSize: 11,
                fontWeight: isCompleted || isToday
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
