import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard.dart';
import 'package:wyrm_desk/settings/settings_state.dart';

import 'calendar_model.dart';
import 'calendar_state.dart';
import 'milestone_form_content.dart';

/// Golden yellow main bento card designated for calendar, date navigation, and life milestones.
class CalendarCard extends ConsumerWidget {
  /// Custom nested content or widget tree.
  final Widget? child;

  /// Callback when a sizing tier is selected from the in-place popup menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active sizing tier for the card.
  final CardSize currentSize;

  const CalendarCard({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> weekdayShortSunday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const List<String> weekdayShortMonday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const List<String> weekdayLabelsSunday = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const List<String> weekdayLabelsMonday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;
    final isFullscreen = currentSize == CardSize.fullscreen;

    return BentoBox(
      color: AppColors.cardYellow,
      borderRadius: 30.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.calendar_today_rounded,
            title: 'Calendar',
            badge: calendarState.milestones.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${calendarState.milestones.length}',
                      style: const TextStyle(
                        color: AppColors.textOnLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  )
                : null,
            onAdd: () => _showAddMilestoneSheet(context, ref),
            onSelectSize: onSelectSize,
            currentSize: currentSize,
            isDarkGlyph: true,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: child ??
                (isSmall
                    ? _buildSmallLayout(context, ref, calendarState, settings)
                    : _buildExpandedLayout(
                        context,
                        ref,
                        calendarState,
                        settings,
                        isFullscreen,
                      )),
          ),
        ],
      ),
    );
  }

  /// Compact single-column view optimized for Small card dimensions with wrap resizing.
  Widget _buildSmallLayout(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
    AppSettingsConfig settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 280;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDynamicBanner(
              ref,
              state,
              isSmall: true,
              isCompact: isCompactHeight,
            ),
            SizedBox(height: isCompactHeight ? 3 : 6),
            _buildMonthNavigation(
              context: context,
              ref: ref,
              state: state,
              isSmall: true,
            ),
            SizedBox(height: isCompactHeight ? 2 : 4),
            Expanded(
              child: _buildCalendarGrid(
                ref,
                state,
                settings.startWeekOnMonday,
                isSmall: true,
              ),
            ),
            if (state.heroMilestone != null && constraints.maxHeight >= 220) ...[
              SizedBox(height: isCompactHeight ? 2 : 4),
              _buildHeroMilestoneTicker(ref, state.heroMilestone!, isSmall: true),
            ],
          ],
        );
      },
    );
  }

  /// Dual-pane split layout for Medium and Fullscreen dimensions.
  Widget _buildExpandedLayout(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
    AppSettingsConfig settings,
    bool isFullscreen,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Pane: Month Calendar with Interactive Jump Controls
        Expanded(
          flex: isFullscreen ? 5 : 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMonthNavigation(context: context, ref: ref, state: state, isSmall: false),
              const SizedBox(height: 8),
              Expanded(
                child: _buildCalendarGrid(
                  ref,
                  state,
                  settings.startWeekOnMonday,
                  isSmall: false,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 14),

        // Vertical Divider
        Container(
          width: 1.0,
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          color: Colors.black.withValues(alpha: 0.1),
        ),

        const SizedBox(width: 14),

        // Right Pane: Temporal & Milestone Inspector
        Expanded(
          flex: isFullscreen ? 5 : 5,
          child: _buildTemporalInspector(context, ref, state, isFullscreen),
        ),
      ],
    );
  }

  /// Dynamic top banner: shows Today or smooth flips to Selected Date with relative distance.
  Widget _buildDynamicBanner(
    WidgetRef ref,
    CalendarState state, {
    required bool isSmall,
    bool isCompact = false,
  }) {
    final today = CalendarState.todayMidnight;
    final isToday = state.selectedDate.year == today.year &&
        state.selectedDate.month == today.month &&
        state.selectedDate.day == today.day;

    final title = isToday
        ? _formatDayAndDate(today)
        : _formatDayAndDate(state.selectedDate);

    final subtitle = isToday
        ? 'Day ${state.dayOfYear}/${state.daysInYear} • Year ${(state.yearProgress * 100).toStringAsFixed(0)}%'
        : state.relativeDistanceText;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: isCompact
                ? Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textOnLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textOnLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          if (!isToday) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => ref.read(calendarProvider.notifier).resetToToday(),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: AppColors.cardYellow,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Month navigation row with Today button, Travel date picker, and month cycling chevrons.
  Widget _buildMonthNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required CalendarState state,
    required bool isSmall,
  }) {
    final monthName = monthNames[state.viewMonth.month - 1];
    final yearString = state.viewMonth.year.toString();
    final today = CalendarState.todayMidnight;
    final isMarkerOnToday = state.selectedDate.year == today.year &&
        state.selectedDate.month == today.month &&
        state.selectedDate.day == today.day &&
        state.viewMonth.year == today.year &&
        state.viewMonth.month == today.month;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$monthName $yearString',
            style: TextStyle(
              color: AppColors.textOnLight,
              fontWeight: FontWeight.w800,
              fontSize: isSmall ? 12 : 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),

        // Quick reset to today only when marker is not on current date
        if (!isMarkerOnToday) ...[
          _buildNavPillButton(
            label: 'Today',
            isSmall: isSmall,
            onTap: () => ref.read(calendarProvider.notifier).resetToToday(),
          ),
          const SizedBox(width: 3),
        ],

        // Travel to date picker
        _buildNavPillButton(
          label: 'Travel',
          isSmall: isSmall,
          onTap: () => _openTravelDatePicker(context, ref, state.selectedDate),
        ),
        const SizedBox(width: 3),

        // Cycle previous month
        _buildCircleButton(
          icon: Icons.chevron_left_rounded,
          size: isSmall ? 24 : 28,
          onTap: () => ref.read(calendarProvider.notifier).prevMonth(),
        ),
        const SizedBox(width: 2),

        // Cycle next month
        _buildCircleButton(
          icon: Icons.chevron_right_rounded,
          size: isSmall ? 24 : 28,
          onTap: () => ref.read(calendarProvider.notifier).nextMonth(),
        ),
      ],
    );
  }

  /// 7-column calendar grid rendering weekday headers and day cells with wrap resizing logic.
  Widget _buildCalendarGrid(
    WidgetRef ref,
    CalendarState state,
    bool startWeekOnMonday, {
    required bool isSmall,
  }) {
    final weekdayLabels = startWeekOnMonday ? weekdayLabelsMonday : weekdayLabelsSunday;
    final year = state.viewMonth.year;
    final month = state.viewMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final offset = startWeekOnMonday
        ? (firstDayOfMonth.weekday - 1)
        : (firstDayOfMonth.weekday % 7);

    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final numWeeks = totalCells ~/ 7;
    final today = CalendarState.todayMidnight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final weekdayHeaderHeight = isSmall ? 14.0 : 18.0;
        final cellSpacing = isSmall ? 2.5 : 3.0;

        return Column(
          children: [
            // Weekday Header Row
            SizedBox(
              height: weekdayHeaderHeight,
              child: Row(
                children: List.generate(7, (index) {
                  final label = weekdayLabels[index];
                  final isWeekend = startWeekOnMonday
                      ? (index == 5 || index == 6)
                      : (index == 0 || index == 6);
                  return Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isWeekend
                              ? Colors.black.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w800,
                          fontSize: isSmall ? 9 : 11,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: isSmall ? 2 : 4),

            // Grid of days with wrap resizing logic: flexible week rows and day cells
            Expanded(
              child: Column(
                children: List.generate(numWeeks, (weekIndex) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: weekIndex < numWeeks - 1 ? cellSpacing : 0,
                      ),
                      child: Row(
                        children: List.generate(7, (colIndex) {
                          final cellIndex = weekIndex * 7 + colIndex;
                          final dayNumber = cellIndex - offset + 1;

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: colIndex < 6 ? cellSpacing : 0,
                              ),
                              child: (dayNumber < 1 || dayNumber > daysInMonth)
                                  ? const SizedBox.shrink()
                                  : _buildDayCell(
                                      ref: ref,
                                      state: state,
                                      today: today,
                                      year: year,
                                      month: month,
                                      dayNumber: dayNumber,
                                      isSmall: isSmall,
                                    ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Individual day cell with soft pill decoration and scaled text fitting.
  Widget _buildDayCell({
    required WidgetRef ref,
    required CalendarState state,
    required DateTime today,
    required int year,
    required int month,
    required int dayNumber,
    required bool isSmall,
  }) {
    final cellDate = DateTime(year, month, dayNumber);
    final isToday = cellDate.year == today.year &&
        cellDate.month == today.month &&
        cellDate.day == today.day;
    final isSelected = cellDate.year == state.selectedDate.year &&
        cellDate.month == state.selectedDate.month &&
        cellDate.day == state.selectedDate.day;

    final dayMilestones = state.milestonesForDate(cellDate);
    final hasMilestone = dayMilestones.isNotEmpty;

    final Color cellBg;
    final Border? cellBorder;
    final Color textColor;

    if (isSelected) {
      cellBg = Colors.black87;
      cellBorder = Border.all(color: Colors.black87, width: 1.0);
      textColor = AppColors.cardYellow;
    } else if (isToday) {
      cellBg = Colors.black.withValues(alpha: 0.12);
      cellBorder = Border.all(color: Colors.black87, width: 1.2);
      textColor = Colors.black87;
    } else {
      cellBg = Colors.black.withValues(alpha: 0.05);
      cellBorder = Border.all(color: Colors.black.withValues(alpha: 0.10), width: 1.0);
      textColor = AppColors.textOnLight;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(calendarProvider.notifier).selectDate(cellDate),
        borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
        child: Container(
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
            border: cellBorder,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: (isSelected || isToday) ? FontWeight.w800 : FontWeight.w600,
                      fontSize: isSmall ? 10 : 12,
                    ),
                  ),
                ),
              ),
              if (hasMilestone)
                Positioned(
                  bottom: isSmall ? 1.5 : 2.5,
                  child: Container(
                    width: isSmall ? 3.0 : 3.5,
                    height: isSmall ? 3.0 : 3.5,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.cardYellow : Colors.black87,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact hero milestone ticker displayed at the bottom of Small mode.
  Widget _buildHeroMilestoneTicker(WidgetRef ref, CalendarMilestone milestone, {required bool isSmall}) {
    final days = milestone.daysRemaining();
    final badgeText = days == 0
        ? 'TODAY'
        : (days > 0 ? '$days DAYS' : '${days.abs()}d AGO');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, size: 13, color: Colors.black87),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              milestone.title,
              style: const TextStyle(
                color: AppColors.textOnLight,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: AppColors.cardYellow,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Temporal Inspector: Selected date typography, relative distance, progress bars, and milestones list.
  Widget _buildTemporalInspector(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
    bool isFullscreen,
  ) {
    final selected = state.selectedDate;
    final dayOfWeek = weekdayShortSunday[selected.weekday % 7];
    final monthName = monthNames[selected.month - 1];

    final existingMilestones = state.milestonesForDate(selected);
    final isAlreadyMilestone = existingMilestones.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected Day Hero Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Big Day Number
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${selected.day}',
                      style: const TextStyle(
                        color: AppColors.cardYellow,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Date and relative text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayOfWeek • $monthName ${selected.year}',
                        style: const TextStyle(
                          color: AppColors.textOnLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.relativeDistanceText,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Set as milestone quick button
                if (!isAlreadyMilestone)
                  InkWell(
                    onTap: () => _showAddMilestoneSheet(context, ref, initialDate: selected),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: Colors.black87),
                          SizedBox(width: 2),
                          Text(
                            'Pin',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Year & Quarter Progress Bars
          _buildProgressBlock(state),

          const SizedBox(height: 12),

          // Milestones Header and List
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 15, color: Colors.black87),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Milestones & Countdowns',
                  style: TextStyle(
                    color: AppColors.textOnLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showAddMilestoneSheet(context, ref, initialDate: selected),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '+ Add',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          if (state.milestones.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Text(
                'No milestones pinned yet. Tap + to add.',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...state.milestones.map((m) => _buildMilestoneTile(ref, m)),
        ],
      ),
    );
  }

  /// Visual Year and Quarter progress bars.
  Widget _buildProgressBlock(CalendarState state) {
    final yearPct = (state.yearProgress * 100).toStringAsFixed(1);
    final quarterPct = (state.quarterProgress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Year Progress
          Row(
            children: [
              Text(
                '${state.selectedDate.year} Progress',
                style: const TextStyle(
                  color: AppColors.textOnLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$yearPct% • Day ${state.dayOfYear}/${state.daysInYear}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.yearProgress,
              minHeight: 6,
              backgroundColor: Colors.black.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
            ),
          ),

          const SizedBox(height: 8),

          // Quarter Progress
          Row(
            children: [
              Text(
                'Q${state.currentQuarter} Progress',
                style: const TextStyle(
                  color: AppColors.textOnLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '$quarterPct%',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.quarterProgress,
              minHeight: 5,
              backgroundColor: Colors.black.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual Milestone Tile in the Inspector.
  Widget _buildMilestoneTile(WidgetRef ref, CalendarMilestone milestone) {
    final days = milestone.daysRemaining();
    final isPast = days < 0;
    final isToday = days == 0;

    final badgeColor = isToday
        ? Colors.black87
        : (isPast ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.15));

    final badgeTextColor = isToday ? AppColors.cardYellow : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Pin status toggle
          InkWell(
            onTap: () => ref.read(calendarProvider.notifier).togglePinMilestone(milestone.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                milestone.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 15,
                color: milestone.isPinned ? Colors.black87 : Colors.black38,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Title & target date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: const TextStyle(
                    color: AppColors.textOnLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${monthNames[milestone.targetDate.month - 1]} ${milestone.targetDate.day}, ${milestone.targetDate.year}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Days remaining capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              milestone.relativeLabel,
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Delete button matching CardEditButton circular look
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(calendarProvider.notifier).deleteMilestone(milestone.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Circular icon button for month navigation.
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 28,
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
          child: Icon(icon, size: size * 0.57, color: Colors.black87),
        ),
      ),
    );
  }

  /// Compact navigation pill button (e.g. Today, Travel).
  Widget _buildNavPillButton({
    required String label,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 5 : 7,
            vertical: isSmall ? 2.5 : 4,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  /// Opens Flutter built-in date picker configured with TRAVEL confirm text.
  Future<void> _openTravelDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime initialDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      confirmText: 'TRAVEL',
      cancelText: 'CANCEL',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black87,
              onPrimary: AppColors.cardYellow,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(calendarProvider.notifier).selectDate(picked);
    }
  }

  /// Opens the full-screen two-pane virtual keyboard milestone editor.
  void _openMilestoneTwoPaneEditor(
    BuildContext context,
    WidgetRef ref, {
    DateTime? initialDate,
  }) {
    final titleController = TextEditingController();
    var selectedTargetDate =
        initialDate ?? ref.read(calendarProvider).selectedDate;
    var isPinned = false;

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setEditorState) {
              void saveMilestone() {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  ref.read(calendarProvider.notifier).addMilestone(
                        title,
                        selectedTargetDate,
                        isPinned: isPinned,
                      );
                  Navigator.of(context).pop();
                }
              }

              return TwoPaneKeyboardScaffold(
                title: 'New Milestone',
                saveLabel: 'Save Milestone',
                saveButtonColor: AppColors.accentOrange,
                saveTextColor: Colors.white,
                onSave: saveMilestone,
                formBuilder: (context, keyboard) {
                  return MilestoneFormContent(
                    titleController: titleController,
                    selectedDate: selectedTargetDate,
                    isPinned: isPinned,
                    onDateChanged: (picked) =>
                        setEditorState(() => selectedTargetDate = picked),
                    onPinnedChanged: (val) =>
                        setEditorState(() => isPinned = val),
                    onChanged: () => setEditorState(() {}),
                  );
                },
                previewBuilder: (context) {
                  return MilestonePreviewCard(
                    title: titleController.text,
                    targetDate: selectedTargetDate,
                    isPinned: isPinned,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Modal bottom sheet to create or pin a milestone, respecting user preference
  /// for classic bottom sheet vs two-pane virtual keyboard editor.
  void _showAddMilestoneSheet(
    BuildContext context,
    WidgetRef ref, {
    DateTime? initialDate,
  }) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.useClassicModalSheet) {
      _openMilestoneTwoPaneEditor(context, ref, initialDate: initialDate);
      return;
    }

    final titleController = TextEditingController();
    var selectedTargetDate =
        initialDate ?? ref.read(calendarProvider).selectedDate;
    var isPinned = false;

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
            void saveMilestone() {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ref.read(calendarProvider.notifier).addMilestone(
                      title,
                      selectedTargetDate,
                      isPinned: isPinned,
                    );
                Navigator.pop(context);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'New Milestone',
                        style: TextStyle(
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
                  MilestoneFormContent(
                    titleController: titleController,
                    selectedDate: selectedTargetDate,
                    isPinned: isPinned,
                    onDateChanged: (picked) =>
                        setModalState(() => selectedTargetDate = picked),
                    onPinnedChanged: (val) =>
                        setModalState(() => isPinned = val),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: saveMilestone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Milestone',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Formats date to human readable string (e.g. "Saturday, Sep 19").
  String _formatDayAndDate(DateTime date) {
    final dayOfWeek = weekdayShortSunday[date.weekday % 7];
    final month = monthNames[date.month - 1].substring(0, 3);
    return '$dayOfWeek, $month ${date.day}';
  }
}
