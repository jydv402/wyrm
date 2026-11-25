import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// 7-column calendar grid with rounded day tiles matching the screenshot.
class CalendarGrid extends ConsumerWidget {
  static const List<String> _weekdayLabelsSunday = [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];
  static const List<String> _weekdayLabelsMonday = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  final CalendarState state;
  final bool startWeekOnMonday;

  const CalendarGrid({
    super.key,
    required this.state,
    required this.startWeekOnMonday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekdayLabels = startWeekOnMonday
        ? _weekdayLabelsMonday
        : _weekdayLabelsSunday;
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
        _buildWeekdayHeader(weekdayLabels),
        const SizedBox(height: 6),
        Expanded(
          child: _buildWeeksList(
            ref,
            numWeeks,
            offset,
            daysInMonth,
            prevMonthDays,
            year,
            month,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(List<String> labels) {
    return Row(
      children: List.generate(7, (index) {
        return Expanded(
          child: Center(
            child: Text(
              labels[index],
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWeeksList(
    WidgetRef ref,
    int numWeeks,
    int offset,
    int daysInMonth,
    int prevMonthDays,
    int year,
    int month,
  ) {
    return Column(
      children: List.generate(numWeeks, (weekIndex) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3.0),
            child: _buildWeekRow(
              ref,
              weekIndex,
              offset,
              daysInMonth,
              prevMonthDays,
              year,
              month,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWeekRow(
    WidgetRef ref,
    int weekIndex,
    int offset,
    int daysInMonth,
    int prevMonthDays,
    int year,
    int month,
  ) {
    return Row(
      children: List.generate(7, (colIndex) {
        final cellIndex = weekIndex * 7 + colIndex;
        final dayNumber = cellIndex - offset + 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _buildCell(
              ref,
              dayNumber,
              daysInMonth,
              prevMonthDays,
              year,
              month,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCell(
    WidgetRef ref,
    int dayNumber,
    int daysInMonth,
    int prevMonthDays,
    int year,
    int month,
  ) {
    final bool isPrev = dayNumber < 1;
    final bool isNext = dayNumber > daysInMonth;
    final int displayDay = isPrev
        ? prevMonthDays + dayNumber
        : (isNext ? dayNumber - daysInMonth : dayNumber);
    final int targetMonth = isPrev ? month - 1 : (isNext ? month + 1 : month);
    final DateTime cellDate = DateTime(year, targetMonth, displayDay);
    final isSelected =
        cellDate.year == state.selectedDate.year &&
        cellDate.month == state.selectedDate.month &&
        cellDate.day == state.selectedDate.day;

    return _CalendarDayCell(
      displayDay: displayDay,
      isSelected: isSelected,
      isAdjacentMonth: isPrev || isNext,
      onTap: () => ref.read(calendarProvider.notifier).selectDate(cellDate),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int displayDay;
  final bool isSelected;
  final bool isAdjacentMonth;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.displayDay,
    required this.isSelected,
    required this.isAdjacentMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.goldFill
              : (isAdjacentMonth
                    ? Colors.white.withValues(alpha: 0.02)
                    : AppColors.glass),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected || isAdjacentMonth
                ? Colors.transparent
                : AppColors.line,
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
            child: Text(
              '$displayDay',
              style: TextStyle(
                color: isSelected
                    ? AppColors.goldInk
                    : (isAdjacentMonth
                          ? AppColors.textMuted
                          : AppColors.textPrimary),
                fontSize: 14.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
