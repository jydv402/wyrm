import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

enum _DuskDatePickerMode { day, month, year }

/// Dusk Glass styled date picker dialog tailored to the desktop app.
///
/// Features interactive Month and Year selector chips in the header:
/// - Tapping Month displays a 12-month grid for single-tap month switching.
/// - Tapping Year displays a scrollable year selection grid.
/// - Selecting either returns back to the interactive day grid.
class DuskDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String confirmText;
  final String cancelText;

  const DuskDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.confirmText = 'TRAVEL',
    this.cancelText = 'CANCEL',
  });

  @override
  State<DuskDatePickerDialog> createState() => _DuskDatePickerDialogState();
}

class _DuskDatePickerDialogState extends State<DuskDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _viewMonth;
  _DuskDatePickerMode _mode = _DuskDatePickerMode.day;
  final ScrollController _yearScrollController = ScrollController();

  static const List<String> _shortMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdayLabels = [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _viewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentYear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_yearScrollController.hasClients) return;
      final yearIndex = _viewMonth.year - widget.firstDate.year;
      // 3 items per row, ~52px per row
      final targetRow = yearIndex ~/ 3;
      final offset = (targetRow * 52.0).clamp(
        0.0,
        _yearScrollController.position.maxScrollExtent,
      );
      _yearScrollController.jumpTo(offset);
    });
  }

  void _toggleMonthMode() {
    setState(() {
      _mode = _mode == _DuskDatePickerMode.month
          ? _DuskDatePickerMode.day
          : _DuskDatePickerMode.month;
    });
  }

  void _toggleYearMode() {
    setState(() {
      _mode = _mode == _DuskDatePickerMode.year
          ? _DuskDatePickerMode.day
          : _DuskDatePickerMode.year;
      if (_mode == _DuskDatePickerMode.year) {
        _scrollToCurrentYear();
      }
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    });
  }

  void _selectMonth(int month) {
    setState(() {
      final daysInNewMonth = DateTime(_viewMonth.year, month + 1, 0).day;
      final safeDay = _selectedDate.day.clamp(1, daysInNewMonth);
      _selectedDate = DateTime(_viewMonth.year, month, safeDay);
      _viewMonth = DateTime(_viewMonth.year, month, 1);
      _mode = _DuskDatePickerMode.day;
    });
  }

  void _selectYear(int year) {
    setState(() {
      final daysInNewMonth = DateTime(year, _viewMonth.month + 1, 0).day;
      final safeDay = _selectedDate.day.clamp(1, daysInNewMonth);
      _selectedDate = DateTime(year, _viewMonth.month, safeDay);
      _viewMonth = DateTime(year, _viewMonth.month, 1);
      _mode = _DuskDatePickerMode.day;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = day;
      if (day.month != _viewMonth.month || day.year != _viewMonth.year) {
        _viewMonth = DateTime(day.year, day.month, 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 24.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Month and Year Chips + Navigation Chevrons
              _buildHeaderControls(),

              const SizedBox(height: 16),

              // Content Area: Day grid / Month grid / Year grid
              SizedBox(
                height: 250,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_mode) {
                    _DuskDatePickerMode.day => _buildDayPicker(),
                    _DuskDatePickerMode.month => _buildMonthPicker(),
                    _DuskDatePickerMode.year => _buildYearPicker(),
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Actions: CANCEL and gold TRAVEL button
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderControls() {
    final currentMonthName =
        monthNames[(_viewMonth.month - 1).clamp(0, monthNames.length - 1)];

    return Row(
      children: [
        // Month Selector Chip
        Flexible(
          child: InkWell(
            onTap: _toggleMonthMode,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _mode == _DuskDatePickerMode.month
                    ? AppColors.goldFill
                    : AppColors.well,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _mode == _DuskDatePickerMode.month
                      ? Colors.transparent
                      : AppColors.line,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      currentMonthName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mode == _DuskDatePickerMode.month
                            ? AppColors.goldInk
                            : AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _mode == _DuskDatePickerMode.month
                        ? Icons.arrow_drop_up_rounded
                        : Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: _mode == _DuskDatePickerMode.month
                        ? AppColors.goldInk
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Year Selector Chip
        InkWell(
          onTap: _toggleYearMode,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _mode == _DuskDatePickerMode.year
                  ? AppColors.goldFill
                  : AppColors.well,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _mode == _DuskDatePickerMode.year
                    ? Colors.transparent
                    : AppColors.line,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_viewMonth.year}',
                  style: TextStyle(
                    color: _mode == _DuskDatePickerMode.year
                        ? AppColors.goldInk
                        : AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _mode == _DuskDatePickerMode.year
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: _mode == _DuskDatePickerMode.year
                      ? AppColors.goldInk
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Chevron buttons (active when in day mode)
        if (_mode == _DuskDatePickerMode.day) ...[
          DuskGlassButton.icon(
            onPressed: () => _shiftMonth(-1),
            size: 32,
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          DuskGlassButton.icon(
            onPressed: () => _shiftMonth(1),
            size: 32,
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayPicker() {
    final year = _viewMonth.year;
    final month = _viewMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prevMonthDays = DateTime(year, month, 0).day;

    // Sunday = 0
    final offset = firstDayOfMonth.weekday % 7;
    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final numWeeks = (totalCells ~/ 7).clamp(4, 6);

    return Column(
      key: const ValueKey('day_picker'),
      children: [
        // Weekday header (S M T W T F S)
        Row(
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
        ),

        const SizedBox(height: 6),

        Expanded(
          child: Column(
            children: List.generate(numWeeks, (weekIndex) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
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

                      final isSelected =
                          cellDate.year == _selectedDate.year &&
                          cellDate.month == _selectedDate.month &&
                          cellDate.day == _selectedDate.day;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: InkWell(
                            onTap: () => _selectDay(cellDate),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.goldFill
                                    : (isPrevMonth || isNextMonth
                                          ? Colors.white.withValues(alpha: 0.02)
                                          : AppColors.glass),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isPrevMonth || isNextMonth
                                            ? Colors.transparent
                                            : AppColors.line),
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$displayDay',
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.goldInk
                                        : (isPrevMonth || isNextMonth
                                              ? AppColors.textMuted
                                              : AppColors.textPrimary),
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
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

  Widget _buildMonthPicker() {
    return GridView.builder(
      key: const ValueKey('month_picker'),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final monthNumber = index + 1;
        final isSelected = _viewMonth.month == monthNumber;

        return InkWell(
          onTap: () => _selectMonth(monthNumber),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.goldFill : AppColors.well,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.line,
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                _shortMonthNames[index],
                style: TextStyle(
                  color: isSelected ? AppColors.goldInk : AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearPicker() {
    final startYear = widget.firstDate.year;
    final totalYears = widget.lastDate.year - startYear + 1;

    return GridView.builder(
      key: const ValueKey('year_picker'),
      controller: _yearScrollController,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: totalYears,
      itemBuilder: (context, index) {
        final year = startYear + index;
        final isSelected = _viewMonth.year == year;

        return InkWell(
          onTap: () => _selectYear(year),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.goldFill : AppColors.well,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.line,
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                '$year',
                style: TextStyle(
                  color: isSelected ? AppColors.goldInk : AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Cancel button
        DuskGlassButton(
          onPressed: () => Navigator.of(context).pop(null),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          label: Text(
            widget.cancelText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Travel button
        DuskGlassButton(
          onPressed: () => Navigator.of(context).pop(_selectedDate),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          isPrimary: true,
          primaryColor: AppColors.goldFill,
          primaryForegroundColor: AppColors.goldInk,
          label: Text(
            widget.confirmText,
            style: const TextStyle(
              color: AppColors.goldInk,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
