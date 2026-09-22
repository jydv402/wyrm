import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard.dart';
import 'package:wyrm_desk/settings/settings_state.dart';

import 'habit_form_content.dart';
import 'habit_model.dart';
import 'habits_state.dart';

/// Sage green bento card designated for daily habit tracking, streak preservation, and weekly check-ins.
class HabitsCard extends ConsumerWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const HabitsCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  /// Standard month label strings.
  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// Resolves an IconData glyph from an iconName token string.
  static IconData resolveIcon(String? name) {
    return resolveHabitIcon(name);
  }

  /// Resolves start of the current week based on startWeekOnMonday setting.
  static DateTime getWeekStart(DateTime referenceDate, bool startWeekOnMonday) {
    final ref = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${habitsState.completedTodayCount()}/${habitsState.habits.length}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        : null;

    return BentoBox(
      color: AppColors.cardSage,
      borderRadius: 30.0,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 14.0 : 16.0,
        vertical: isSmall ? 10.0 : 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.bolt_rounded,
            title: 'Habits',
            badge: badgeWidget,
            onAdd: () => _showHabitFormSheet(context, ref),
            onSelectSize: onSelectSize,
            currentSize: currentSize,
            isDarkGlyph: true,
          ),
          SizedBox(height: isSmall ? 4 : 8),
          Expanded(
            child: isSmall
                ? _buildSmallLayout(context, ref, habitsState, settings)
                : _buildExpandedLayout(context, ref, habitsState, settings),
          ),
        ],
      ),
    );
  }

  /// Compact Small card layout rendering habit carousel with weekly strip.
  Widget _buildSmallLayout(
    BuildContext context,
    WidgetRef ref,
    HabitsState state,
    AppSettingsConfig settings,
  ) {
    if (state.habits.isEmpty) {
      return _buildEmptyState(context, ref);
    }

    final activeHabit = state.activeHabit!;
    final today = DateTime.now();
    final weekStart = getWeekStart(today, settings.startWeekOnMonday);
    final isDoneToday = activeHabit.isCompletedOn(today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isUltraCompact = constraints.maxHeight < 150;
        final isCompactHeight = constraints.maxHeight < 240;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carousel Navigation Bar
            Row(
              children: [
                _buildCircleButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => ref.read(habitsProvider.notifier).cycleCarousel(-1),
                  size: isUltraCompact ? 22 : (isCompactHeight ? 24 : 26),
                ),
                const SizedBox(width: 5),
                Icon(
                  resolveIcon(activeHabit.iconName),
                  size: isUltraCompact ? 13 : (isCompactHeight ? 14 : 16),
                  color: Colors.black87,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    activeHabit.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textOnLight,
                      fontWeight: FontWeight.w800,
                      fontSize: isUltraCompact ? 12 : (isCompactHeight ? 13 : 14),
                    ),
                  ),
                ),
                Text(
                  '${state.selectedCarouselIndex + 1}/${state.habits.length}',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: isUltraCompact ? 9 : (isCompactHeight ? 10 : 11),
                  ),
                ),
                const SizedBox(width: 5),
                _buildCircleButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => ref.read(habitsProvider.notifier).cycleCarousel(1),
                  size: isUltraCompact ? 22 : (isCompactHeight ? 24 : 26),
                ),
              ],
            ),
            SizedBox(height: isUltraCompact ? 3 : (isCompactHeight ? 5 : 8)),

            // Active Habit Details and Today Quick Action
            Row(
              children: [
                // Streak capsule
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isUltraCompact ? 5 : 7,
                    vertical: isUltraCompact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🔥',
                        style: TextStyle(fontSize: isUltraCompact ? 9 : 11),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${activeHabit.currentStreak()}d',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: isUltraCompact ? 9 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),

                // Target progress label
                if (activeHabit.type == HabitType.numeric)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isUltraCompact ? 5 : 7,
                      vertical: isUltraCompact ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDoneToday
                          ? Colors.black87
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${activeHabit.completionCountOn(today)}/${activeHabit.targetValue} ${activeHabit.unit ?? ""}'.trim(),
                      style: TextStyle(
                        color: isDoneToday ? AppColors.cardSage : Colors.black87,
                        fontSize: isUltraCompact ? 9 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                const Spacer(),

                // Today Quick Action (Binary toggle or Numeric steppers)
                if (activeHabit.type == HabitType.binary)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => ref
                          .read(habitsProvider.notifier)
                          .toggleCompletion(activeHabit.id, today),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isUltraCompact ? 7 : 10,
                          vertical: isUltraCompact ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDoneToday
                              ? Colors.black87
                              : Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDoneToday
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: isUltraCompact ? 12 : 14,
                              color: isDoneToday ? AppColors.cardSage : Colors.black87,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isDoneToday ? 'Done' : 'Today',
                              style: TextStyle(
                                color: isDoneToday ? AppColors.cardSage : Colors.black87,
                                fontSize: isUltraCompact ? 9 : 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStepperButton(
                        icon: Icons.remove_rounded,
                        onTap: () => ref
                            .read(habitsProvider.notifier)
                            .stepCompletion(activeHabit.id, -1, today),
                        size: isUltraCompact ? 20 : (isCompactHeight ? 22 : 26),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${activeHabit.completionCountOn(today)}',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: isUltraCompact ? 11 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 5),
                      _buildStepperButton(
                        icon: Icons.add_rounded,
                        onTap: () => ref
                            .read(habitsProvider.notifier)
                            .stepCompletion(activeHabit.id, 1, today),
                        size: isUltraCompact ? 20 : (isCompactHeight ? 22 : 26),
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: isUltraCompact ? 4 : (isCompactHeight ? 6 : 10)),

            // 7-Day Interactive Week Strip
            Expanded(
              child: _buildWeekStrip(
                ref: ref,
                habit: activeHabit,
                weekStart: weekStart,
                today: today,
                startWeekOnMonday: settings.startWeekOnMonday,
                isUltraCompact: isUltraCompact,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Interactive 7-day strip where tapping any day toggles or steps the habit for that day.
  Widget _buildWeekStrip({
    required WidgetRef ref,
    required HabitItem habit,
    required DateTime weekStart,
    required DateTime today,
    required bool startWeekOnMonday,
    bool isUltraCompact = false,
  }) {
    final dayLabels = !startWeekOnMonday
        ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(7, (index) {
        final dayDate = weekStart.add(Duration(days: index));
        final isToday = dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day;
        final isCompleted = habit.isCompletedOn(dayDate);
        final count = habit.completionCountOn(dayDate);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (habit.type == HabitType.binary) {
                    ref.read(habitsProvider.notifier).toggleCompletion(habit.id, dayDate);
                  } else {
                    ref.read(habitsProvider.notifier).stepCompletion(habit.id, 1, dayDate);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.black87
                        : (count > 0
                            ? Colors.black.withValues(alpha: 0.20)
                            : Colors.black.withValues(alpha: 0.07)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? Colors.black87
                          : (isCompleted
                              ? Colors.black87
                              : Colors.black.withValues(alpha: 0.12)),
                      width: isToday ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dayLabels[index],
                              style: TextStyle(
                                color: isCompleted
                                    ? AppColors.cardSage
                                    : (isToday ? Colors.black87 : Colors.black54),
                                fontSize: isUltraCompact ? 9 : 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              habit.type == HabitType.numeric && count > 0 && !isCompleted
                                  ? '$count'
                                  : '${dayDate.day}',
                              style: TextStyle(
                                color: isCompleted ? AppColors.cardSage : Colors.black87,
                                fontSize: isUltraCompact ? 10 : 11,
                                fontWeight: isToday || isCompleted
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            if (isCompleted) ...[
                              const SizedBox(height: 2),
                              Icon(
                                Icons.check_rounded,
                                size: isUltraCompact ? 8 : 9,
                                color: AppColors.cardSage,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Multi-column Card Grid layout for Medium and Fullscreen modes.
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
    final bool isFullscreen = currentSize == CardSize.fullscreen;
    final int crossAxisCount = isFullscreen ? 2 : 1;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 280.0,
      ),
      itemCount: state.habits.length,
      itemBuilder: (context, index) {
        final habit = state.habits[index];
        return _buildHabitCardTile(
          context: context,
          ref: ref,
          habit: habit,
          today: today,
          weekStart: weekStart,
          settings: settings,
        );
      },
    );
  }

  /// Individual habit card tile within the Medium/Fullscreen grid with weekly strip and GitHub heatmap.
  Widget _buildHabitCardTile({
    required BuildContext context,
    required WidgetRef ref,
    required HabitItem habit,
    required DateTime today,
    required DateTime weekStart,
    required AppSettingsConfig settings,
  }) {
    final isDoneToday = habit.isCompletedOn(today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon, Title, Streak, and Options Menu
          Row(
            children: [
              Icon(
                resolveIcon(habit.iconName),
                size: 16,
                color: Colors.black87,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  habit.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textOnLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🔥 ${habit.currentStreak()}d',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.black54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showHabitFormSheet(context, ref, habitToEdit: habit);
                  } else if (value == 'delete') {
                    ref.read(habitsProvider.notifier).deleteHabit(habit.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: AppColors.accentRed)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Today Quick Action Row
          Row(
            children: [
              if (habit.type == HabitType.numeric)
                Expanded(
                  child: Text(
                    '${habit.completionCountOn(today)}/${habit.targetValue} ${habit.unit ?? ""}'.trim(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    isDoneToday ? 'Completed today' : 'Pending today',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDoneToday ? Colors.black87 : Colors.black54,
                      fontSize: 11,
                      fontWeight: isDoneToday ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              if (habit.type == HabitType.binary)
                InkWell(
                  onTap: () => ref.read(habitsProvider.notifier).toggleCompletion(habit.id, today),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDoneToday ? Colors.black87 : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDoneToday ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 13,
                          color: isDoneToday ? AppColors.cardSage : Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDoneToday ? 'Done' : 'Check',
                          style: TextStyle(
                            color: isDoneToday ? AppColors.cardSage : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepperButton(
                      icon: Icons.remove_rounded,
                      onTap: () => ref.read(habitsProvider.notifier).stepCompletion(habit.id, -1, today),
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${habit.completionCountOn(today)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStepperButton(
                      icon: Icons.add_rounded,
                      onTap: () => ref.read(habitsProvider.notifier).stepCompletion(habit.id, 1, today),
                      size: 22,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 7-Day Current Week Strip
          SizedBox(
            height: 42,
            child: _buildWeekStrip(
              ref: ref,
              habit: habit,
              weekStart: weekStart,
              today: today,
              startWeekOnMonday: settings.startWeekOnMonday,
            ),
          ),
          const SizedBox(height: 6),

          // Calendar-Style Heatmap Widget (5x7 / 6x7 grid)
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
  }

  /// Calendar-style monthly contribution heatmap showing daily dots in a 7-column x 5/6-row matrix.
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
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$completedCount/$totalDays days',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          SizedBox(
                            width: 14,
                            child: Center(
                              child: Text(
                                weekdayLabels[i],
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    for (var w = 0; w < weeks.length; w++) ...[
                      if (w > 0) const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var d = 0; d < 7; d++) ...[
                            if (d > 0) const SizedBox(width: 3),
                            _buildHeatmapDot(weeks[w][d]),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual rounded square dot for the calendar-style monthly heatmap.
  Widget _buildHeatmapDot(HeatmapCellData cell) {
    if (!cell.isCurrentMonth) {
      return const SizedBox(
        width: 14,
        height: 14,
      );
    }

    Color dotColor;
    Border? border;

    if (cell.isCompleted) {
      dotColor = Colors.black87;
    } else if (cell.intensity > 0.6) {
      dotColor = Colors.black.withValues(alpha: 0.65);
    } else if (cell.intensity > 0.3) {
      dotColor = Colors.black.withValues(alpha: 0.45);
    } else if (cell.intensity > 0.0) {
      dotColor = Colors.black.withValues(alpha: 0.25);
    } else if (cell.isFuture) {
      dotColor = Colors.black.withValues(alpha: 0.04);
      border = Border.all(
        color: Colors.black.withValues(alpha: 0.08),
        width: 0.8,
      );
    } else {
      dotColor = Colors.black.withValues(alpha: 0.08);
    }

    if (cell.isToday) {
      border = Border.all(
        color: Colors.black87,
        width: 1.2,
      );
    }

    return Tooltip(
      message: cell.date != null
          ? '${monthNames[cell.date!.month - 1]} ${cell.dayNumber}: ${cell.isCompleted ? "Done" : (cell.count > 0 ? "${cell.count} achieved" : "Missed")}'
          : '',
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: dotColor,
          borderRadius: BorderRadius.circular(2.5),
          border: border,
        ),
      ),
    );
  }

  /// Empty state rendered when no habits are created yet.
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 140;

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 6 : 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: isCompact ? 18 : 24,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: isCompact ? 4 : 8),
                Text(
                  'No habits yet',
                  style: TextStyle(
                    color: AppColors.textOnLight,
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 12 : 14,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Tap \'+\' to track your first daily habit',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: isCompact ? 6 : 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showHabitFormSheet(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 12,
                        vertical: isCompact ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '+ Add Habit',
                        style: TextStyle(
                          color: AppColors.cardSage,
                          fontSize: isCompact ? 10 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Circular icon button for carousel navigation.
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 26,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size * 0.62, color: Colors.black87),
        ),
      ),
    );
  }

  /// Circular stepper icon button (+ and -).
  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 24,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size * 0.6, color: Colors.black87),
        ),
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
    final titleController =
        TextEditingController(text: habitToEdit?.title ?? '');
    final unitController = TextEditingController(text: habitToEdit?.unit ?? '');
    var habitType = habitToEdit?.type ?? HabitType.binary;
    var targetCount =
        habitToEdit?.targetValue ?? (habitType == HabitType.numeric ? 8 : 1);
    var selectedIcon = habitToEdit?.iconName ?? 'bolt';

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setEditorState) {
              void saveHabit() {
                final text = titleController.text.trim();
                if (text.isEmpty) return;

                final unit = unitController.text.trim().isEmpty
                    ? null
                    : unitController.text.trim();

                if (isEditing) {
                  final updated = habitToEdit.copyWith(
                    title: text,
                    type: habitType,
                    targetValue: targetCount,
                    unit: unit,
                    iconName: selectedIcon,
                  );
                  ref.read(habitsProvider.notifier).editHabit(updated);
                } else {
                  final newHabit = HabitItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: text,
                    type: habitType,
                    targetValue: targetCount,
                    unit: unit,
                    iconName: selectedIcon,
                    colorHex: '#A0D2B4',
                    createdAt: DateTime.now(),
                  );
                  ref.read(habitsProvider.notifier).addHabit(newHabit);
                }
                Navigator.of(context).pop();
              }

              return TwoPaneKeyboardScaffold(
                title: isEditing ? 'Edit Habit' : 'New Habit',
                saveLabel: isEditing ? 'Save Changes' : 'Create Habit',
                saveButtonColor: AppColors.cardSage,
                saveTextColor: AppColors.textOnLight,
                onSave: saveHabit,
                formBuilder: (context, keyboard) {
                  return HabitFormContent(
                    titleController: titleController,
                    unitController: unitController,
                    habitType: habitType,
                    targetCount: targetCount,
                    selectedIcon: selectedIcon,
                    isEditing: isEditing,
                    onTypeChanged: (type) =>
                        setEditorState(() => habitType = type),
                    onTargetCountChanged: (count) =>
                        setEditorState(() => targetCount = count),
                    onIconChanged: (icon) =>
                        setEditorState(() => selectedIcon = icon),
                    onChanged: () => setEditorState(() {}),
                  );
                },
                previewBuilder: (context) {
                  return HabitPreviewTile(
                    title: titleController.text,
                    type: habitType,
                    targetCount: targetCount,
                    unit: unitController.text.trim().isEmpty
                        ? null
                        : unitController.text.trim(),
                    iconName: selectedIcon,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Opens the habit creation/edit flow, respecting user preference for
  /// classic bottom sheet vs two-pane virtual keyboard editor.
  void _showHabitFormSheet(
    BuildContext context,
    WidgetRef ref, {
    HabitItem? habitToEdit,
  }) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.useClassicModalSheet) {
      _openHabitTwoPaneEditor(context, ref, habitToEdit: habitToEdit);
      return;
    }

    final isEditing = habitToEdit != null;
    final titleController =
        TextEditingController(text: habitToEdit?.title ?? '');
    final unitController = TextEditingController(text: habitToEdit?.unit ?? '');
    var habitType = habitToEdit?.type ?? HabitType.binary;
    var targetCount =
        habitToEdit?.targetValue ?? (habitType == HabitType.numeric ? 8 : 1);
    var selectedIcon = habitToEdit?.iconName ?? 'bolt';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void saveHabit() {
              final text = titleController.text.trim();
              if (text.isEmpty) return;

              final unit = unitController.text.trim().isEmpty
                  ? null
                  : unitController.text.trim();

              if (isEditing) {
                final updated = habitToEdit.copyWith(
                  title: text,
                  type: habitType,
                  targetValue: targetCount,
                  unit: unit,
                  iconName: selectedIcon,
                );
                ref.read(habitsProvider.notifier).editHabit(updated);
              } else {
                final newHabit = HabitItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: text,
                  type: habitType,
                  targetValue: targetCount,
                  unit: unit,
                  iconName: selectedIcon,
                  colorHex: '#A0D2B4',
                  createdAt: DateTime.now(),
                );
                ref.read(habitsProvider.notifier).addHabit(newHabit);
              }
              Navigator.pop(context);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEditing ? 'Edit Habit' : 'New Habit',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    HabitFormContent(
                      titleController: titleController,
                      unitController: unitController,
                      habitType: habitType,
                      targetCount: targetCount,
                      selectedIcon: selectedIcon,
                      isEditing: isEditing,
                      onTypeChanged: (type) =>
                          setModalState(() => habitType = type),
                      onTargetCountChanged: (count) =>
                          setModalState(() => targetCount = count),
                      onIconChanged: (icon) =>
                          setModalState(() => selectedIcon = icon),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cardSage,
                              foregroundColor: AppColors.textOnLight,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saveHabit,
                            child: Text(
                              isEditing ? 'Save Changes' : 'Create Habit',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
