import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_form_content.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

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
      onAdd: () => _openHabitTwoPaneEditor(context, ref),
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
          ? _HabitsCarouselView(state: habitsState, settings: settings)
          : _HabitsExpandedGrid(
              state: habitsState,
              settings: settings,
              isFullscreen: currentSize == CardSize.fullscreen,
            ),
    );
  }
}

/// Compact Small card view: Empty state matching reference, or habit carousel with 7-day dot matrix.
class _HabitsCarouselView extends ConsumerWidget {
  final HabitsState state;
  final AppSettingsConfig settings;

  const _HabitsCarouselView({required this.state, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.habits.isEmpty) {
      return _HabitsEmptyState();
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
            // Carousel Navigation Bar
            Row(
              children: [
                DuskGlassButton.icon(
                  onPressed: () =>
                      ref.read(habitsProvider.notifier).cycleCarousel(-1),
                  size: isUltraCompact ? 22 : (isCompactHeight ? 26 : 30),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: isUltraCompact ? 22 : (isCompactHeight ? 26 : 30),
                  height: isUltraCompact ? 22 : (isCompactHeight ? 26 : 30),
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
                      fontSize: isUltraCompact
                          ? 12
                          : (isCompactHeight ? 13.5 : 15),
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
                  onPressed: () =>
                      ref.read(habitsProvider.notifier).cycleCarousel(1),
                  size: isUltraCompact ? 22 : (isCompactHeight ? 26 : 30),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            SizedBox(height: isUltraCompact ? 4 : 8),

            // Middle status bar (action button + streak)
            Row(
              children: [
                if (activeHabit.type == HabitType.numeric)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.well,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line, width: 1.0),
                    ),
                    child: Text(
                      '${activeHabit.completionCountOn(today)}/${activeHabit.targetValue} ${activeHabit.unit ?? ""}'
                          .trim(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                const Spacer(),

                // Done / Quick Action Button
                if (activeHabit.type == HabitType.binary)
                  DuskGlassButton(
                    onPressed: () => ref
                        .read(habitsProvider.notifier)
                        .toggleCompletion(activeHabit.id, today),
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
                      color: isDoneToday
                          ? AppColors.tealInk
                          : AppColors.textPrimary,
                    ),
                    label: Text(
                      isDoneToday ? 'Done' : 'Mark done',
                      style: TextStyle(
                        color: isDoneToday
                            ? AppColors.tealInk
                            : AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DuskGlassButton.icon(
                        onPressed: () => ref
                            .read(habitsProvider.notifier)
                            .stepCompletion(activeHabit.id, -1, today),
                        size: isUltraCompact ? 24 : 30,
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
                            .stepCompletion(activeHabit.id, 1, today),
                        size: isUltraCompact ? 24 : 30,
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            if (!isUltraCompact) ...[
              const SizedBox(height: 10),
              // 7-day dot matrix
              _HabitWeekDots(
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

/// 7-day circular completion dots matching assets/web Dusk Glass .week__dot
class _HabitWeekDots extends ConsumerWidget {
  final HabitItem habit;
  final DateTime weekStart;
  final DateTime today;
  final bool startWeekOnMonday;

  const _HabitWeekDots({
    required this.habit,
    required this.weekStart,
    required this.today,
    required this.startWeekOnMonday,
  });

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

        return InkWell(
          onTap: () {
            if (habit.type == HabitType.binary) {
              ref
                  .read(habitsProvider.notifier)
                  .toggleCompletion(habit.id, dayDate);
            } else {
              ref
                  .read(habitsProvider.notifier)
                  .stepCompletion(habit.id, 1, dayDate);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayLabels[index],
                  style: TextStyle(
                    color: isToday ? AppColors.tealAccent : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.tealFill : AppColors.well,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? Colors.transparent
                          : (isToday
                                ? AppColors.tealAccent
                                : AppColors.lineStrong),
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
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.tealInk,
                        )
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
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Empty state matching the reference screenshot: sprout circle, title, subtitle, "+ Add a habit".
class _HabitsEmptyState extends ConsumerWidget {
  const _HabitsEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DuskCardEmptyState(
      icon: Icons.spa_rounded,
      accentColor: AppColors.tealAccent,
      title: 'No habits for today',
      subtitle: 'Build the life you want, one habit at a time.',
      circleSize: 72.0,
      circleBorderWidth: 1.2,
      iconGap: 14.0,
      scaleDown: true,
      action: DuskGlassButton(
        onPressed: () => _openHabitTwoPaneEditor(context, ref),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        icon: const Icon(
          Icons.add_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        label: const Text(
          'Add a habit',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Expanded Multi-Column Grid layout for Medium & Fullscreen modes.
class _HabitsExpandedGrid extends ConsumerWidget {
  final HabitsState state;
  final AppSettingsConfig settings;
  final bool isFullscreen;

  const _HabitsExpandedGrid({
    required this.state,
    required this.settings,
    required this.isFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.habits.isEmpty) {
      return const _HabitsEmptyState();
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
        mainAxisExtent: 270.0,
      ),
      itemCount: state.habits.length,
      itemBuilder: (context, index) {
        return _HabitGridTile(
          habit: state.habits[index],
          today: today,
          weekStart: weekStart,
          startWeekOnMonday: settings.startWeekOnMonday,
        );
      },
    );
  }
}

/// One habit tile in the expanded grid: header row, week dots, and monthly heatmap.
class _HabitGridTile extends ConsumerWidget {
  final HabitItem habit;
  final DateTime today;
  final DateTime weekStart;
  final bool startWeekOnMonday;

  const _HabitGridTile({
    required this.habit,
    required this.today,
    required this.weekStart,
    required this.startWeekOnMonday,
  });

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
          Row(
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
                onPressed: () =>
                    _openHabitTwoPaneEditor(context, ref, habitToEdit: habit),
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
          ),
          const SizedBox(height: 8),
          _HabitWeekDots(
            habit: habit,
            weekStart: weekStart,
            today: today,
            startWeekOnMonday: startWeekOnMonday,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _HabitHeatmap(
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

/// Calendar-style monthly contribution heatmap showing daily activity dots.
class _HabitHeatmap extends StatelessWidget {
  final HabitItem habit;
  final DateTime today;
  final bool startWeekOnMonday;

  const _HabitHeatmap({
    required this.habit,
    required this.today,
    required this.startWeekOnMonday,
  });

  @override
  Widget build(BuildContext context) {
    final weeks = habit.getMonthlyCalendarWeeks(
      today,
      startWeekOnMonday: startWeekOnMonday,
      todayDate: today,
    );
    final monthName = monthNames[today.month - 1];
    final completedCount = habit.monthCompletedDaysCount(today);
    final totalDays = DateTime(today.year, today.month + 1, 0).day;
    final weekdayLabels = startWeekOnMonday
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$monthName Activity',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$completedCount/$totalDays days',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: weekdayLabels.map((lbl) {
                        return Container(
                          width: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          child: Text(
                            lbl,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 3),
                    ...weeks.map((week) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: week.map((cell) {
                            Color dotColor;
                            Border? border;

                            if (cell.date == null) {
                              dotColor = Colors.transparent;
                            } else if (cell.isCompleted) {
                              dotColor = AppColors.tealAccent;
                            } else if (cell.count > 0) {
                              dotColor = AppColors.tealAccent.withValues(
                                alpha: 0.4,
                              );
                            } else {
                              dotColor = AppColors.glass;
                              border = Border.all(
                                color: AppColors.line,
                                width: 1.0,
                              );
                            }

                            if (cell.isToday) {
                              border = Border.all(
                                color: AppColors.textPrimary,
                                width: 1.2,
                              );
                            }

                            return Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: dotColor,
                                borderRadius: BorderRadius.circular(4),
                                border: border,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the full-screen two-pane virtual keyboard habit editor.
void _openHabitTwoPaneEditor(
  BuildContext context,
  WidgetRef ref, {
  HabitItem? habitToEdit,
}) {
  final isEditing = habitToEdit != null;
  final titleController = TextEditingController(text: habitToEdit?.title ?? '');
  final unitController = TextEditingController(text: habitToEdit?.unit ?? '');
  var habitType = habitToEdit?.type ?? HabitType.binary;
  var targetValue =
      habitToEdit?.targetValue ?? (habitType == HabitType.numeric ? 8 : 1);
  var iconName = habitToEdit?.iconName ?? 'bolt';

  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setEditorState) {
            void saveHabit() {
              final title = titleController.text.trim();
              final unit = unitController.text.trim();
              if (title.isNotEmpty) {
                if (isEditing) {
                  final updated = habitToEdit.copyWith(
                    title: title,
                    type: habitType,
                    targetValue: targetValue,
                    unit: habitType == HabitType.numeric
                        ? (unit.isEmpty ? null : unit)
                        : null,
                    iconName: iconName,
                  );
                  ref.read(habitsProvider.notifier).editHabit(updated);
                } else {
                  final newHabit = HabitItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    type: habitType,
                    targetValue: targetValue,
                    unit: habitType == HabitType.numeric
                        ? (unit.isEmpty ? null : unit)
                        : null,
                    iconName: iconName,
                    createdAt: DateTime.now(),
                  );
                  ref.read(habitsProvider.notifier).addHabit(newHabit);
                }
                Navigator.of(context).pop();
              }
            }

            return TwoPaneKeyboardScaffold(
              title: isEditing ? 'Edit Habit' : 'New Habit',
              saveLabel: isEditing ? 'Save Changes' : 'Save Habit',
              saveButtonColor: AppColors.tealFill,
              saveTextColor: Colors.white,
              onSave: saveHabit,
              formBuilder: (context, keyboard) {
                return HabitFormContent(
                  titleController: titleController,
                  unitController: unitController,
                  habitType: habitType,
                  targetCount: targetValue,
                  selectedIcon: iconName,
                  onTypeChanged: (type) =>
                      setEditorState(() => habitType = type),
                  onTargetCountChanged: (val) =>
                      setEditorState(() => targetValue = val),
                  onIconChanged: (icon) =>
                      setEditorState(() => iconName = icon),
                  onChanged: () => setEditorState(() {}),
                );
              },
              previewBuilder: (context) {
                return HabitPreviewTile(
                  title: titleController.text,
                  type: habitType,
                  targetCount: targetValue,
                  unit: unitController.text.trim().isEmpty
                      ? null
                      : unitController.text.trim(),
                  iconName: iconName,
                );
              },
            );
          },
        );
      },
    ),
  );
}
