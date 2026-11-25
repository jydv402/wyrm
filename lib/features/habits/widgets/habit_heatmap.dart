import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';

/// Calendar-style monthly contribution heatmap showing daily activity dots.
class HabitHeatmap extends StatelessWidget {
  final HabitItem habit;
  final DateTime today;
  final bool startWeekOnMonday;

  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.today,
    required this.startWeekOnMonday,
  });

  Widget _buildHeader(String monthName, int completedCount, int totalDays) {
    return Row(
      spacing: 4.0,
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
        Text(
          '$completedCount/$totalDays days',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(List<String> weekdayLabels) {
    return Row(
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
    );
  }

  Widget _buildCell(HeatmapCellData cell) {
    if (!cell.isCurrentMonth || cell.date == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(width: 16, height: 16),
      );
    }

    Color dotColor;
    Border? border;

    if (cell.isCompleted) {
      dotColor = AppColors.tealAccent;
    } else if (cell.count > 0) {
      dotColor = AppColors.tealAccent.withValues(alpha: 0.4);
    } else {
      dotColor = AppColors.glass;
      border = Border.all(color: AppColors.line, width: 1.0);
    }

    if (cell.isToday) {
      border = Border.all(color: AppColors.textPrimary, width: 1.2);
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
  }

  Widget _buildCalendarMatrix(
    List<List<HeatmapCellData>> weeks,
    List<String> weekdayLabels,
  ) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWeekdayLabels(weekdayLabels),
            const SizedBox(height: 3),
            ...weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: week.map(_buildCell).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

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
        spacing: 6.0,
        children: [
          _buildHeader(monthName, completedCount, totalDays),
          Expanded(child: _buildCalendarMatrix(weeks, weekdayLabels)),
        ],
      ),
    );
  }
}
