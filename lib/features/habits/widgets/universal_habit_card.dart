import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';
import 'package:wyrm_desk/features/habits/widgets/habit_heatmap.dart';
import 'package:wyrm_desk/features/habits/widgets/habit_week_dots.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// The Universal Habit Card matching the new layout specification:
/// - Top Banner: Glyph + Habit Name on left; Streak pill + Complete action +
///   Edit button + Delete button on right.
/// - Bottom Section: Two rounded sub-panels side-by-side for Week view and Month view.
class UniversalHabitCard extends ConsumerWidget {
  final HabitItem habit;
  final DateTime today;
  final DateTime weekStart;
  final bool startWeekOnMonday;
  final VoidCallback? onEdit;

  const UniversalHabitCard({
    super.key,
    required this.habit,
    required this.today,
    required this.weekStart,
    required this.startWeekOnMonday,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoneToday = habit.isCompletedOn(today);
    final streak = habit.currentStreak(today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.well,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDoneToday
                  ? AppColors.tealAccent.withValues(alpha: 0.5)
                  : AppColors.line,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10.0,
            children: [
              HabitCardTopBanner(
                habit: habit,
                today: today,
                streak: streak,
                isDoneToday: isDoneToday,
                onEdit: onEdit,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8.0,
                  children: [
                    Expanded(
                      flex: 5,
                      child: HabitWeekPanel(
                        habit: habit,
                        weekStart: weekStart,
                        today: today,
                        startWeekOnMonday: startWeekOnMonday,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: HabitHeatmap(
                        habit: habit,
                        today: today,
                        startWeekOnMonday: startWeekOnMonday,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (constraints.maxHeight < 210 || constraints.maxWidth < 370) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth < 370 ? 370 : constraints.maxWidth,
              height: constraints.maxHeight < 210 ? 210 : constraints.maxHeight,
              child: cardContent,
            ),
          );
        }

        return cardContent;
      },
    );
  }
}

/// Top banner row holding Glyph, Title, Streak pill, Complete button, Edit, and Delete actions.
class HabitCardTopBanner extends ConsumerWidget {
  final HabitItem habit;
  final DateTime today;
  final int streak;
  final bool isDoneToday;
  final VoidCallback? onEdit;

  const HabitCardTopBanner({
    super.key,
    required this.habit,
    required this.today,
    required this.streak,
    required this.isDoneToday,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      spacing: 8.0,
      children: [
        // Glyph circle
        Container(
          width: 36,
          height: 36,
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
            size: 18,
            color: AppColors.tealAccent,
          ),
        ),
        const SizedBox(width: 2), // Originally was 10
        // Habit title
        Expanded(
          child: Text(
            habit.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Trailing controls (Streak, Complete, Edit, Delete)
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            spacing: 8.0,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Streak rounded rectangular pill
              HabitStreakPill(streak: streak),

              // Complete action button / stepper
              HabitCompleteAction(
                habit: habit,
                today: today,
                isDoneToday: isDoneToday,
              ),

              // Edit button
              if (onEdit != null) ...[
                DuskGlassButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              // Delete button
              DuskGlassButton.icon(
                onPressed: () =>
                    ref.read(habitsProvider.notifier).deleteHabit(habit.id),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppColors.accentRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded rectangular streak pill showing active unbroken streak count.
class HabitStreakPill extends StatelessWidget {
  final int streak;

  const HabitStreakPill({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final hasStreak = streak > 0;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasStreak
            ? AppColors.goldAccent.withValues(alpha: 0.12)
            : AppColors.glass,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: hasStreak
              ? AppColors.goldAccent.withValues(alpha: 0.35)
              : AppColors.line,
          width: 1.0,
        ),
      ),
      child: Text(
        hasStreak ? '🔥 ${streak}d' : '0d',
        style: TextStyle(
          color: hasStreak ? AppColors.goldAccent : AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Complete action: circular checkmark button for binary habits, or compact stepper for numeric.
class HabitCompleteAction extends ConsumerWidget {
  final HabitItem habit;
  final DateTime today;
  final bool isDoneToday;

  const HabitCompleteAction({
    super.key,
    required this.habit,
    required this.today,
    required this.isDoneToday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (habit.type == HabitType.binary) {
      return DuskGlassButton.icon(
        onPressed: () =>
            ref.read(habitsProvider.notifier).toggleCompletion(habit.id, today),
        isPrimary: isDoneToday,
        primaryColor: AppColors.tealFill,
        icon: Icon(
          Icons.check_rounded,
          size: 16,
          color: isDoneToday ? AppColors.tealInk : AppColors.textPrimary,
        ),
      );
    }

    final count = habit.completionCountOn(today);
    final unitText = habit.unit?.isNotEmpty == true ? ' ${habit.unit}' : '';

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDoneToday
            ? AppColors.tealFill.withValues(alpha: 0.14)
            : AppColors.glass,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        spacing: 8.0,
        mainAxisSize: MainAxisSize.min,
        children: [
          DuskGlassButton.icon(
            onPressed: () => ref
                .read(habitsProvider.notifier)
                .stepCompletion(habit.id, -1, today),
            icon: const Icon(
              Icons.remove_rounded,
              size: 13,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '$count/${habit.targetValue}$unitText',
            style: TextStyle(
              color: isDoneToday ? AppColors.tealAccent : AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          DuskGlassButton.icon(
            onPressed: () => ref
                .read(habitsProvider.notifier)
                .stepCompletion(habit.id, 1, today),
            icon: const Icon(
              Icons.add_rounded,
              size: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-panel for the 7-day Week View containing the rectangular day pills.
class HabitWeekPanel extends StatelessWidget {
  final HabitItem habit;
  final DateTime weekStart;
  final DateTime today;
  final bool startWeekOnMonday;

  const HabitWeekPanel({
    super.key,
    required this.habit,
    required this.weekStart,
    required this.today,
    required this.startWeekOnMonday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 6.0,
        children: [
          const Row(
            spacing: 4.0,
            children: [
              Expanded(
                child: Text(
                  'Week View',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '7 Days',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: HabitWeekDots(
                habit: habit,
                weekStart: weekStart,
                today: today,
                startWeekOnMonday: startWeekOnMonday,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
