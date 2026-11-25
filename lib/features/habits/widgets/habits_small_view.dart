import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_empty_state.dart';
import 'package:wyrm_desk/features/habits/widgets/universal_habit_card.dart';

/// Compact Small card view: Directly renders the focused Universal Habit Card.
class HabitsSmallView extends ConsumerWidget {
  final HabitsState state;
  final AppSettingsConfig settings;
  final VoidCallback? onAdd;
  final void Function(HabitItem habit)? onEdit;

  const HabitsSmallView({
    super.key,
    required this.state,
    required this.settings,
    this.onAdd,
    this.onEdit,
  });

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

    return UniversalHabitCard(
      key: ValueKey(activeHabit.id),
      habit: activeHabit,
      today: today,
      weekStart: weekStart,
      startWeekOnMonday: settings.startWeekOnMonday,
      onEdit: onEdit != null ? () => onEdit!(activeHabit) : null,
    );
  }
}
