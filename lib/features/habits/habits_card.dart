import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_carousel_view.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_expanded_grid.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

export 'package:wyrm_desk/features/habits/habit_editor_screen.dart';

/// Dusk Glass Habits card with teal gradient, empty state matching the reference,
/// and interactive 7-day completion matrices.
class HabitsCard extends ConsumerWidget {
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;

  const HabitsCard({
    super.key,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  /// Resolves midnight of the week containing [referenceDate].
  static DateTime getWeekStart(DateTime referenceDate, bool startWeekOnMonday) {
    final ref = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final daysToSubtract = startWeekOnMonday
        ? ref.weekday - 1
        : ref.weekday % 7;
    return ref.subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsState = ref.watch(habitsProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.teal,
      icon: Icons.eco_rounded,
      title: 'Habits',
      badge: DuskCountBadge(
        label: habitsState.habits.isEmpty
            ? null
            : '${habitsState.completedTodayCount()}/${habitsState.habits.length}',
        color: AppColors.tealAccent,
      ),
      onAdd: () => openHabitTwoPaneEditor(context, ref),
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      headerGap: 12.0,
      child: isSmall
          ? HabitsCarouselView(
              state: habitsState,
              settings: settings,
              onAdd: () => openHabitTwoPaneEditor(context, ref),
            )
          : HabitsExpandedGrid(
              state: habitsState,
              settings: settings,
              isFullscreen: currentSize == CardSize.fullscreen,
              onAdd: () => openHabitTwoPaneEditor(context, ref),
              onEdit: (habit) =>
                  openHabitTwoPaneEditor(context, ref, habitToEdit: habit),
            ),
    );
  }
}

/// Opens the full-screen two-pane virtual keyboard habit editor.
void openHabitTwoPaneEditor(
  BuildContext context,
  WidgetRef ref, {
  HabitItem? habitToEdit,
}) {
  context.push(AppRoutes.habitEditor, extra: habitToEdit);
}
