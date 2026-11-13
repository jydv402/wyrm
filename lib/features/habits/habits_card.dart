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
import 'package:wyrm_desk/widgets/dusk_card_header.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Dusk Glass Habits card with teal gradient, empty state matching the reference,
/// and interactive 7-day completion matrices.
class HabitsCard extends ConsumerWidget {
  final Widget? child;
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;

  const HabitsCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  static IconData resolveIcon(String? name) {
    return resolveHabitIcon(name) ?? Icons.bolt_rounded;
  }

  static DateTime getWeekStart(DateTime referenceDate, bool startWeekOnMonday) {
    final ref = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    if (!startWeekOnMonday) {
      final daysToSubtract = ref.weekday % 7;
      return ref.subtract(Duration(days: daysToSubtract));
    } else {
      final daysToSubtract = ref.weekday - 1;
      return ref.subtract(Duration(days: daysToSubtract));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsState = ref.watch(habitsProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;

    final badgeWidget = habitsState.habits.isNotEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tealAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.tealAccent.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Text(
              '${habitsState.completedTodayCount()}/${habitsState.habits.length}',
              style: const TextStyle(
                color: AppColors.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null;

    return DuskGlassPanel(
      tone: AppColors.teal,
      borderRadius: 32.0,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuskCardHeader(
            icon: Icons.eco_rounded,
            title: 'Habits',
            accentColor: AppColors.tealAccent,
            badge: badgeWidget,
            onAdd: () => _showHabitFormSheet(context, ref),
            addColor: AppColors.tealFill,
            addForegroundColor: AppColors.tealInk,
            onSelectSize: onSelectSize,
            currentSize: currentSize,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isSmall
                ? _buildSmallLayout(context, ref, habitsState, settings)
                : _buildExpandedLayout(context, ref, habitsState, settings),
          ),
        ],
      ),
    );
  }

  /// Compact Small card view: Empty state matching reference, or habit carousel with 7-day dot matrix.
  Widget _buildSmallLayout(
    BuildContext context,
    WidgetRef ref,
    HabitsState state,
    AppSettingsConfig settings,
  ) {
    if (state.habits.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    final activeHabit = state.activeHabit ?? state.habits.first;
    final today = DateTime.now();
    final weekStart = getWeekStart(today, settings.startWeekOnMonday);
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
              _buildDuskWeekDots(
                ref: ref,
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

  /// 7-day circular completion dots matching assets/web Dusk Glass .week__dot
  Widget _buildDuskWeekDots({
    required WidgetRef ref,
    required HabitItem habit,
    required DateTime weekStart,
    required DateTime today,
    required bool startWeekOnMonday,
  }) {
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

  /// Empty state matching the reference screenshot: sprout circle, title, subtitle, "+ Add a habit".
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular sprout icon badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.tealAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.tealAccent.withValues(alpha: 0.38),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.spa_rounded,
                size: 34,
                color: AppColors.tealAccent,
              ),
            ),

            const SizedBox(height: 14),

            // Title
            const Text(
              'No habits for today',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 4),

            // Subtitle
            const Text(
              'Build the life you want, one habit at a time.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 18),

            // + Add a habit button
            DuskGlassButton(
              onPressed: () => _showHabitFormSheet(context, ref),
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
          ],
        ),
      ),
    );
  }

  /// Expanded Multi-Column Grid layout for Medium & Fullscreen modes.
  Widget _buildExpandedLayout(
    BuildContext context,
    WidgetRef ref,
    HabitsState state,
    AppSettingsConfig settings,
  ) {
    if (state.habits.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    final today = DateTime.now();
    final weekStart = getWeekStart(today, settings.startWeekOnMonday);
    final isFullscreen = currentSize == CardSize.fullscreen;

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
        final habit = state.habits[index];
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
                        _showHabitFormSheet(context, ref, habitToEdit: habit),
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
              _buildDuskWeekDots(
                ref: ref,
                habit: habit,
                weekStart: weekStart,
                today: today,
                startWeekOnMonday: settings.startWeekOnMonday,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildCalendarHeatmap(
                  habit: habit,
                  today: today,
                  startWeekOnMonday: settings.startWeekOnMonday,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Calendar-style monthly contribution heatmap showing daily activity dots.
  Widget _buildCalendarHeatmap({
    required HabitItem habit,
    required DateTime today,
    required bool startWeekOnMonday,
  }) {
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

  /// Opens the full-screen two-pane virtual keyboard habit editor.
  void _openHabitTwoPaneEditor(
    BuildContext context,
    WidgetRef ref, {
    HabitItem? habitToEdit,
  }) {
    final isEditing = habitToEdit != null;
    final titleController = TextEditingController(
      text: habitToEdit?.title ?? '',
    );
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

  /// Opens the 2-pane virtual keyboard editor for creating or editing habits.
  void _showHabitFormSheet(
    BuildContext context,
    WidgetRef ref, {
    HabitItem? habitToEdit,
  }) {
    _openHabitTwoPaneEditor(context, ref, habitToEdit: habitToEdit);
  }
}
