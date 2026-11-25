import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Interactive day grid for DuskDatePickerDialog.
class DatePickerDayGrid extends StatelessWidget {
  static const List<String> _weekdayLabels = [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];

  final DateTime viewMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDay;

  const DatePickerDayGrid({
    super.key,
    required this.viewMonth,
    required this.selectedDate,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final year = viewMonth.year;
    final month = viewMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prevMonthDays = DateTime(year, month, 0).day;

    final offset = firstDayOfMonth.weekday % 7;
    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final numWeeks = (totalCells ~/ 7).clamp(4, 6);

    return Column(
      spacing: 6.0,
      children: [
        _buildWeekdayHeader(),
        Expanded(
          child: _buildWeeksList(
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

  Widget _buildWeekdayHeader() {
    return Row(
      children: List.generate(7, (index) {
        return Expanded(
          child: Center(
            child: Text(
              _weekdayLabels[index],
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
        cellDate.year == selectedDate.year &&
        cellDate.month == selectedDate.month &&
        cellDate.day == selectedDate.day;

    return _DatePickerDayCell(
      displayDay: displayDay,
      isSelected: isSelected,
      isAdjacentMonth: isPrev || isNext,
      onTap: () => onSelectDay(cellDate),
    );
  }
}

class _DatePickerDayCell extends StatelessWidget {
  final int displayDay;
  final bool isSelected;
  final bool isAdjacentMonth;
  final VoidCallback onTap;

  const _DatePickerDayCell({
    required this.displayDay,
    required this.isSelected,
    required this.isAdjacentMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.goldFill
              : (isAdjacentMonth
                    ? Colors.white.withValues(alpha: 0.02)
                    : AppColors.glass),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected || isAdjacentMonth
                ? Colors.transparent
                : AppColors.line,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            '$displayDay\u200B',
            style: TextStyle(
              color: isSelected
                  ? AppColors.goldInk
                  : (isAdjacentMonth
                        ? AppColors.textMuted
                        : AppColors.textPrimary),
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
