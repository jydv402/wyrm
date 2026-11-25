import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_expanded_grid.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_small_view.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

export 'package:wyrm_desk/features/habits/habit_editor_screen.dart';

/// Dusk Glass Habits card with teal gradient, empty state matching the reference,
/// header chevron navigation in Small mode, and responsive universal habit cards.
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

    final badgeLabel = habitsState.habits.isEmpty
        ? null
        : isSmall
        ? '${habitsState.selectedCarouselIndex + 1}/${habitsState.habits.length}'
        : '${habitsState.habits.length}';

    return DuskCardScaffold(
      tone: AppColors.teal,
      icon: Icons.eco_rounded,
      title: 'Habits',
      badge: DuskCountBadge(label: badgeLabel, color: AppColors.tealAccent),
      onAdd: () => openHabitTwoPaneEditor(context, ref),
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      extraActions: isSmall && habitsState.habits.isNotEmpty
          ? [
              DuskGlassButton.icon(
                key: const ValueKey('habit_prev_btn'),
                onPressed: () =>
                    ref.read(habitsProvider.notifier).cycleCarousel(-1),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              DuskGlassButton.icon(
                key: const ValueKey('habit_next_btn'),
                onPressed: () =>
                    ref.read(habitsProvider.notifier).cycleCarousel(1),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
            ]
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      headerGap: 12.0,
      child: isSmall
          ? HabitsSmallView(
              state: habitsState,
              settings: settings,
              onAdd: () => openHabitTwoPaneEditor(context, ref),
              onEdit: (habit) =>
                  openHabitTwoPaneEditor(context, ref, habitToEdit: habit),
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
