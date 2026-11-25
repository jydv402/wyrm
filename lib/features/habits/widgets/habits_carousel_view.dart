import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/form/habit_icon_picker.dart';
import 'package:wyrm_desk/features/habits/widgets/habit_week_dots.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_empty_state.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Compact Small card view: Empty state matching reference, or habit carousel with 7-day dot matrix.
class HabitsCarouselView extends ConsumerWidget {
  final HabitsState state;
  final AppSettingsConfig settings;
  final VoidCallback? onAdd;

  const HabitsCarouselView({
    super.key,
    required this.state,
    required this.settings,
    this.onAdd,
  });

  Widget _buildNavigationBar(
    WidgetRef ref,
    HabitItem activeHabit, {
    required bool isUltraCompact,
    required bool isCompactHeight,
  }) {
    final navButtonSize = isUltraCompact
        ? 22.0
        : (isCompactHeight ? 26.0 : 30.0);

    return Row(
      children: [
        DuskGlassButton.icon(
          onPressed: () => ref.read(habitsProvider.notifier).cycleCarousel(-1),
          size: navButtonSize,
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: navButtonSize,
          height: navButtonSize,
          decoration: BoxDecoration(
            color: AppColors.tealAccent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.tealAccent.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: buildHabitGlyph(
            activeHabit.iconName,
            size: isUltraCompact ? 12 : 15,
            color: AppColors.tealAccent,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            activeHabit.title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: isUltraCompact ? 12 : (isCompactHeight ? 13.5 : 15),
            ),
          ),
        ),
        Text(
          '${state.selectedCarouselIndex + 1}/${state.habits.length}',
          style: TextStyle(
            color: AppColors.tealAccent,
            fontWeight: FontWeight.w700,
            fontSize: isUltraCompact ? 10 : 11,
          ),
        ),
        const SizedBox(width: 4),
        DuskGlassButton.icon(
          onPressed: () => ref.read(habitsProvider.notifier).cycleCarousel(1),
          size: navButtonSize,
          icon: const Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNumericBadge(HabitItem habit, DateTime today) {
    final count = habit.completionCountOn(today);
    final unitText = habit.unit?.isNotEmpty == true ? ' ${habit.unit}' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Text(
        '$count/${habit.targetValue}$unitText',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBinaryActionButton(
    WidgetRef ref,
    HabitItem habit,
    DateTime today,
    bool isDoneToday,
    bool isUltraCompact,
  ) {
    return DuskGlassButton(
      onPressed: () =>
          ref.read(habitsProvider.notifier).toggleCompletion(habit.id, today),
      height: isUltraCompact ? 24 : 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      isPrimary: isDoneToday,
      primaryColor: AppColors.teal.fill,
      primaryForegroundColor: AppColors.tealInk,
      icon: Icon(
        isDoneToday
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size: 14,
        color: isDoneToday ? AppColors.tealInk : AppColors.textPrimary,
      ),
      label: Text(
        isDoneToday ? 'Done' : 'Mark done',
        style: TextStyle(
          color: isDoneToday ? AppColors.tealInk : AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildNumericStepper(
    WidgetRef ref,
    HabitItem habit,
    DateTime today,
    bool isUltraCompact,
  ) {
    final btnSize = isUltraCompact ? 24.0 : 30.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DuskGlassButton.icon(
          onPressed: () => ref
              .read(habitsProvider.notifier)
              .stepCompletion(habit.id, -1, today),
          size: btnSize,
          icon: const Icon(
            Icons.remove_rounded,
            size: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        DuskGlassButton.icon(
          onPressed: () => ref
              .read(habitsProvider.notifier)
              .stepCompletion(habit.id, 1, today),
          size: btnSize,
          icon: const Icon(
            Icons.add_rounded,
            size: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(
    WidgetRef ref,
    HabitItem habit,
    DateTime today,
    bool isDoneToday,
    bool isUltraCompact,
  ) {
    return Row(
      children: [
        if (habit.type == HabitType.numeric) _buildNumericBadge(habit, today),
        const Spacer(),
        if (habit.type == HabitType.binary)
          _buildBinaryActionButton(
            ref,
            habit,
            today,
            isDoneToday,
            isUltraCompact,
          )
        else
          _buildNumericStepper(ref, habit, today, isUltraCompact),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.habits.isEmpty) {
      return HabitsEmptyState(onAdd: onAdd);
    }

    final activeHabit = state.activeHabit ?? state.habits.first;
    final today = DateTime.now();
    final weekStart = HabitsCard.getWeekStart(
      today,
      settings.startWeekOnMonday,
    );
    final isDoneToday = activeHabit.isCompletedOn(today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isUltraCompact = constraints.maxHeight < 150;
        final isCompactHeight = constraints.maxHeight < 240;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNavigationBar(
              ref,
              activeHabit,
              isUltraCompact: isUltraCompact,
              isCompactHeight: isCompactHeight,
            ),
            SizedBox(height: isUltraCompact ? 4 : 8),
            _buildActionBar(
              ref,
              activeHabit,
              today,
              isDoneToday,
              isUltraCompact,
            ),
            if (!isUltraCompact) ...[
              const SizedBox(height: 10),
              HabitWeekDots(
                habit: activeHabit,
                weekStart: weekStart,
                today: today,
                startWeekOnMonday: settings.startWeekOnMonday,
              ),
            ],
          ],
        );

        if (isUltraCompact) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(width: constraints.maxWidth, child: content),
          );
        }

        return content;
      },
    );
  }
}
