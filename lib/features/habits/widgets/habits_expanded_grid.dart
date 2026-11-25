import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_empty_state.dart';
import 'package:wyrm_desk/features/habits/widgets/universal_habit_card.dart';

/// Expanded Multi-Column Grid layout for Medium (1 column) & Fullscreen (2 columns) modes.
class HabitsExpandedGrid extends ConsumerWidget {
  final HabitsState state;
  final AppSettingsConfig settings;
  final bool isFullscreen;
  final VoidCallback? onAdd;
  final void Function(HabitItem habit)? onEdit;

  const HabitsExpandedGrid({
    super.key,
    required this.state,
    required this.settings,
    required this.isFullscreen,
    this.onAdd,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.habits.isEmpty) {
      return HabitsEmptyState(onAdd: onAdd);
    }

    final today = DateTime.now();
    final weekStart = HabitsCard.getWeekStart(
      today,
      settings.startWeekOnMonday,
    );

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isFullscreen ? 2 : 1,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 220.0,
      ),
      itemCount: state.habits.length,
      itemBuilder: (context, index) {
        final habit = state.habits[index];
        return UniversalHabitCard(
          key: ValueKey(habit.id),
          habit: habit,
          today: today,
          weekStart: weekStart,
          startWeekOnMonday: settings.startWeekOnMonday,
          onEdit: onEdit != null ? () => onEdit!(habit) : null,
        );
      },
    );
  }
}
