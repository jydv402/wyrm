import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wyrm_desk/calendar/calendar_state.dart';
import 'package:wyrm_desk/calendar/milestone_form_content.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/widgets/dusk_card_header.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Dusk Glass Calendar card with gold/olive gradient, date banner pill,
/// and responsive day grid matching the screenshot.
class CalendarCard extends ConsumerWidget {
  final Widget? child;
  final ValueChanged<CardSize>? onSelectSize;
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

  static const List<String> weekdayLabelsSunday = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const List<String> weekdayLabelsMonday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;
    final isFullscreen = currentSize == CardSize.fullscreen;

    final badgeWidget = calendarState.milestones.isNotEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.goldAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.goldAccent.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Text(
              '${calendarState.milestones.length}',
              style: const TextStyle(
                color: AppColors.goldAccent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          )
        : null;

    return DuskGlassPanel(
      tone: AppColors.gold,
      borderRadius: 32.0,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuskCardHeader(
            icon: Icons.calendar_today_rounded,
            title: 'Calendar',
            accentColor: AppColors.goldAccent,
            badge: badgeWidget,
            onAdd: () => _showAddMilestoneSheet(context, ref),
            addColor: null, // Circular glass '+' button
            onSelectSize: onSelectSize,
            currentSize: currentSize,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: isSmall
                ? _buildSmallLayout(context, ref, calendarState, settings)
                : _buildExpandedLayout(
                    context,
                    ref,
                    calendarState,
                    settings,
                    isFullscreen,
                  ),
          ),
        ],
      ),
    );
  }

  /// Compact Small card layout matching screenshot reference.
  Widget _buildSmallLayout(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
    AppSettingsConfig settings,
  ) {
    final monthName = monthNames[state.viewMonth.month - 1];
    final yearString = state.viewMonth.year.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Info & Navigation Pill Bar
        _buildDuskDateBanner(context, ref, state),

        const SizedBox(height: 12),

        // Month Title (e.g. September 2026)
        Text(
          '$monthName $yearString',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),

        const SizedBox(height: 8),

        // Day Grid
        Expanded(
          child: _buildDuskCalendarGrid(
            ref,
            state,
            settings.startWeekOnMonday,
            isSmall: true,
          ),
        ),
      ],
    );
  }

  /// Top Date Banner Bar matching reference screenshot:
  /// Left: [Sat, Sep 19 • Day 262/365 · Year 72%]
  /// Right: [Today] [Travel] [<] [>]
  Widget _buildDuskDateBanner(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) {
    final today = CalendarState.todayMidnight;
    final isSelectedToday = state.selectedDate.year == today.year &&
        state.selectedDate.month == today.month &&
        state.selectedDate.day == today.day;
    final isMarkerOnToday = isSelectedToday &&
        state.viewMonth.year == today.year &&
        state.viewMonth.month == today.month;

    final dateStr = DateFormat('EEE, MMM d').format(state.selectedDate);
    final telemetry = isSelectedToday
        ? 'Day ${state.dayOfYear}/${state.daysInYear} · Year ${(state.yearProgress * 100).toStringAsFixed(0)}%'
        : state.relativeDistanceText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final btnHeight = isCompact ? 32.0 : 38.0;
        final btnPadding = EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 12.0);
        final chevronSize = isCompact ? 32.0 : 38.0;

        return Row(
          children: [
            // Left telemetry pill
            Expanded(
              child: Container(
                height: btnHeight,
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 14),
                decoration: BoxDecoration(
                  color: AppColors.well,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line, width: 1.0),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.goldAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        telemetry,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (!isMarkerOnToday) ...[
              SizedBox(width: isCompact ? 4 : 6),
              // Today button
              DuskGlassButton(
                onPressed: () => ref.read(calendarProvider.notifier).resetToToday(),
                height: btnHeight,
                padding: btnPadding,
                label: const Text(
                  'Today',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            SizedBox(width: isCompact ? 4 : 6),

            // Travel button
            DuskGlassButton(
              onPressed: () => _openTravelDatePicker(context, ref, state.selectedDate),
              height: btnHeight,
              padding: btnPadding,
              label: const Text(
                'Travel',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            SizedBox(width: isCompact ? 4 : 6),

            // Chevron previous month
            DuskGlassButton.icon(
              onPressed: () => ref.read(calendarProvider.notifier).prevMonth(),
              size: chevronSize,
              icon: Icon(Icons.chevron_left_rounded, size: isCompact ? 16 : 18, color: AppColors.textPrimary),
            ),

            SizedBox(width: isCompact ? 4 : 6),

            // Chevron next month
            DuskGlassButton.icon(
              onPressed: () => ref.read(calendarProvider.notifier).nextMonth(),
              size: chevronSize,
              icon: Icon(Icons.chevron_right_rounded, size: isCompact ? 16 : 18, color: AppColors.textPrimary),
            ),
          ],
        );
      },
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.goldAccent,
              onPrimary: Colors.black,
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

  /// 7-column calendar grid with rounded day tiles matching the screenshot.
  Widget _buildDuskCalendarGrid(
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
    final prevMonthDays = DateTime(year, month, 0).day;

    final offset = startWeekOnMonday
        ? (firstDayOfMonth.weekday - 1)
        : (firstDayOfMonth.weekday % 7);

    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final numWeeks = totalCells ~/ 7;

    return Column(
      children: [
        // Weekday Row (S M T W T F S)
        Row(
          children: List.generate(7, (index) {
            return Expanded(
              child: Center(
                child: Text(
                  weekdayLabels[index],
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 6),

        // Week rows and day cells
        Expanded(
          child: Column(
            children: List.generate(numWeeks, (weekIndex) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: List.generate(7, (colIndex) {
                      final cellIndex = weekIndex * 7 + colIndex;
                      final dayNumber = cellIndex - offset + 1;

                      final bool isPrevMonth = dayNumber < 1;
                      final bool isNextMonth = dayNumber > daysInMonth;

                      final int displayDay;
                      final DateTime cellDate;

                      if (isPrevMonth) {
                        displayDay = prevMonthDays + dayNumber;
                        cellDate = DateTime(year, month - 1, displayDay);
                      } else if (isNextMonth) {
                        displayDay = dayNumber - daysInMonth;
                        cellDate = DateTime(year, month + 1, displayDay);
                      } else {
                        displayDay = dayNumber;
                        cellDate = DateTime(year, month, displayDay);
                      }

                      final isSelected = cellDate.year == state.selectedDate.year &&
                          cellDate.month == state.selectedDate.month &&
                          cellDate.day == state.selectedDate.day;

                      final hasMilestone = state.milestonesForDate(cellDate).isNotEmpty;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3.0),
                          child: InkWell(
                            onTap: () {
                              ref.read(calendarProvider.notifier).selectDate(cellDate);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.goldFill
                                    : (isPrevMonth || isNextMonth
                                        ? Colors.white.withValues(alpha: 0.02)
                                        : AppColors.glass),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isPrevMonth || isNextMonth
                                          ? Colors.transparent
                                          : AppColors.line),
                                  width: 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.goldFill.withValues(alpha: 0.5),
                                          blurRadius: 14,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$displayDay',
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.goldInk
                                              : (isPrevMonth || isNextMonth
                                                  ? AppColors.textMuted
                                                  : AppColors.textPrimary),
                                          fontSize: 14.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                      if (isSelected || hasMilestone)
                                        Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.goldInk
                                                : AppColors.goldAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
  }

  /// Dual-pane expanded view for Medium and Fullscreen modes.
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
        // Left Pane: Calendar Month Grid
        Expanded(
          flex: 6,
          child: _buildSmallLayout(context, ref, state, settings),
        ),

        const SizedBox(width: 16),

        // Vertical divider
        Container(width: 1.0, color: AppColors.lineStrong),

        const SizedBox(width: 16),

        // Right Pane: Milestones & Event Inspector
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Milestones & Countdowns',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DuskGlassButton(
                    onPressed: () => _showAddMilestoneSheet(context, ref),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.textPrimary),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.milestones.isEmpty
                    ? const Center(
                        child: Text(
                          'No milestones recorded yet.\nTap Add to track an upcoming event.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: state.milestones.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final milestone = state.milestones[index];
                          final formattedDate = DateFormat('MMM d, yyyy').format(milestone.targetDate);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.well,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.goldAccent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.flag_rounded, size: 16, color: AppColors.goldAccent),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        milestone.title,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  milestone.relativeLabel,
                                  style: const TextStyle(
                                    color: AppColors.goldAccent,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                DuskGlassButton.icon(
                                  onPressed: () => ref.read(calendarProvider.notifier).deleteMilestone(milestone.id),
                                  size: 28,
                                  icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
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
                saveButtonColor: AppColors.goldAccent,
                saveTextColor: Colors.black,
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

  /// Presents the Dusk Glass modal sheet for adding a milestone.
  void _showAddMilestoneSheet(BuildContext context, WidgetRef ref, {DateTime? initialDate}) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.useClassicModalSheet) {
      _openMilestoneTwoPaneEditor(context, ref, initialDate: initialDate);
      return;
    }

    final titleController = TextEditingController();
    var selectedDate = initialDate ?? ref.read(calendarProvider).selectedDate;
    var isPinned = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void saveMilestone() {
              final text = titleController.text.trim();
              if (text.isEmpty) return;

              ref.read(calendarProvider.notifier).addMilestone(
                    text,
                    selectedDate,
                    isPinned: isPinned,
                  );
              Navigator.of(context).pop();
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppColors.lineStrong, width: 1.0),
              ),
              child: SingleChildScrollView(
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        DuskGlassButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          size: 32,
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MilestoneFormContent(
                      titleController: titleController,
                      selectedDate: selectedDate,
                      isPinned: isPinned,
                      onDateChanged: (d) => setSheetState(() => selectedDate = d),
                      onPinnedChanged: (p) => setSheetState(() => isPinned = p),
                    ),
                    const SizedBox(height: 20),
                    DuskGlassButton(
                      onPressed: saveMilestone,
                      isPrimary: true,
                      primaryColor: AppColors.goldFill,
                      primaryForegroundColor: AppColors.goldInk,
                      height: 46,
                      label: const Text(
                        'Add Milestone',
                        style: TextStyle(
                          color: AppColors.goldInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
