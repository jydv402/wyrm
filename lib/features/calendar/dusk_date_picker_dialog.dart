import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_actions.dart';
import 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_day_grid.dart';
import 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_header.dart';
import 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_month_grid.dart';
import 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_year_selector.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

export 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_actions.dart';
export 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_day_grid.dart';
export 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_header.dart';
export 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_month_grid.dart';
export 'package:wyrm_desk/features/calendar/widgets/date_picker/date_picker_year_selector.dart';

/// Dusk Glass styled date picker dialog tailored to the desktop app.
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
    this.confirmText = 'Travel',
    this.cancelText = 'Cancel',
  });

  @override
  State<DuskDatePickerDialog> createState() => _DuskDatePickerDialogState();
}

class _DuskDatePickerDialogState extends State<DuskDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _viewMonth;
  DuskDatePickerMode _mode = DuskDatePickerMode.day;
  final ScrollController _yearScrollController = ScrollController();
  late int _minLoadedYear;
  late int _maxLoadedYear;
  bool _isExtendingYears = false;
  double _lastItemWidth = 100.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _viewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _initYearRange();
    _yearScrollController.addListener(_onYearScroll);
  }

  @override
  void dispose() {
    _yearScrollController.removeListener(_onYearScroll);
    _yearScrollController.dispose();
    super.dispose();
  }

  void _initYearRange() {
    final curYear = _viewMonth.year;
    var start = curYear - 30;
    var end = curYear + 29;
    if (start < widget.firstDate.year) {
      final diff = widget.firstDate.year - start;
      start = widget.firstDate.year;
      end = (end + diff).clamp(widget.firstDate.year, widget.lastDate.year);
    }
    if (end > widget.lastDate.year) {
      final diff = end - widget.lastDate.year;
      end = widget.lastDate.year;
      start = (start - diff).clamp(widget.firstDate.year, widget.lastDate.year);
    }
    _minLoadedYear = start;
    _maxLoadedYear = end;
  }

  void _onYearScroll() {
    if (!_yearScrollController.hasClients || _isExtendingYears) return;

    final pos = _yearScrollController.position;
    if (pos.pixels <= 150.0 && _minLoadedYear > widget.firstDate.year) {
      _extendYearsUpward();
    } else if (pos.maxScrollExtent - pos.pixels <= 150.0 &&
        _maxLoadedYear < widget.lastDate.year) {
      _extendYearsDownward();
    }
  }

  void _extendYearsDownward() {
    if (_maxLoadedYear >= widget.lastDate.year) return;
    _isExtendingYears = true;
    final toAdd = (widget.lastDate.year - _maxLoadedYear).clamp(1, 30);
    setState(() => _maxLoadedYear += toAdd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isExtendingYears = false;
    });
  }

  void _extendYearsUpward() {
    if (_minLoadedYear <= widget.firstDate.year) return;
    _isExtendingYears = true;
    final available = _minLoadedYear - widget.firstDate.year;
    final toAdd = available >= 30
        ? 30
        : (available >= 3 ? (available ~/ 3) * 3 : available);
    if (toAdd <= 0) {
      _isExtendingYears = false;
      return;
    }

    final addedRows = (toAdd / 3.0).ceil();
    final rowHeight = (_lastItemWidth / 2.2) + 10.0;
    final heightToAdd = addedRows * rowHeight;

    setState(() => _minLoadedYear -= toAdd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_yearScrollController.hasClients) {
        _yearScrollController.jumpTo(
          _yearScrollController.offset + heightToAdd,
        );
      }
      _isExtendingYears = false;
    });
  }

  void _scrollToCurrentYear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_yearScrollController.hasClients) return;
      final yearIndex = _viewMonth.year - _minLoadedYear;
      final rowHeight = (_lastItemWidth / 2.2) + 10.0;
      final vpHeight = _yearScrollController.position.viewportDimension;
      final target =
          ((yearIndex / 3).floor() * rowHeight) -
          (vpHeight / 2.0) +
          (rowHeight / 2.0);
      final offset = target.clamp(
        0.0,
        _yearScrollController.position.maxScrollExtent,
      );
      _yearScrollController.jumpTo(offset);
    });
  }

  void _toggleMonthMode() {
    setState(() {
      _mode = _mode == DuskDatePickerMode.month
          ? DuskDatePickerMode.day
          : DuskDatePickerMode.month;
    });
  }

  void _toggleYearMode() {
    setState(() {
      _mode = _mode == DuskDatePickerMode.year
          ? DuskDatePickerMode.day
          : DuskDatePickerMode.year;
      if (_mode == DuskDatePickerMode.year) {
        if (_viewMonth.year < _minLoadedYear ||
            _viewMonth.year > _maxLoadedYear) {
          _initYearRange();
        }
        _scrollToCurrentYear();
      }
    });
  }

  void _shiftMonth(int delta) {
    final nextMonth = DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    final firstAllowed = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      1,
    );
    final lastAllowed = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      1,
    );
    if (nextMonth.isBefore(firstAllowed) || nextMonth.isAfter(lastAllowed)) {
      return;
    }
    setState(() => _viewMonth = nextMonth);
  }

  void _selectMonth(int month) {
    setState(() {
      final daysInNewMonth = DateTime(_viewMonth.year, month + 1, 0).day;
      final safeDay = _selectedDate.day.clamp(1, daysInNewMonth);
      _selectedDate = DateTime(_viewMonth.year, month, safeDay);
      _viewMonth = DateTime(_viewMonth.year, month, 1);
      _mode = DuskDatePickerMode.day;
    });
  }

  void _selectYear(int year) {
    setState(() {
      final daysInNewMonth = DateTime(year, _viewMonth.month + 1, 0).day;
      final safeDay = _selectedDate.day.clamp(1, daysInNewMonth);
      _selectedDate = DateTime(year, _viewMonth.month, safeDay);
      _viewMonth = DateTime(year, _viewMonth.month, 1);
      _mode = DuskDatePickerMode.day;
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
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.5).clamp(380.0, 720.0);
    final dialogHeight = (screenSize.height * 0.5).clamp(440.0, 760.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16.0),
      child: DuskGlassPanel(
        tone: AppColors.gold,
        borderRadius: 32.0,
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14.0,
          children: [
            DatePickerHeader(
              selectedDate: _selectedDate,
              viewMonth: _viewMonth,
              mode: _mode,
              onToggleMonth: _toggleMonthMode,
              onToggleYear: _toggleYearMode,
              onShiftMonth: _shiftMonth,
              onClose: () => context.pop(null),
            ),
            Expanded(child: _buildPickerBody()),
            DatePickerActions(
              cancelText: widget.cancelText,
              confirmText: widget.confirmText,
              onCancel: () => context.pop(null),
              onConfirm: () => context.pop(_selectedDate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_mode) {
        DuskDatePickerMode.day => DatePickerDayGrid(
          viewMonth: _viewMonth,
          selectedDate: _selectedDate,
          onSelectDay: _selectDay,
        ),
        DuskDatePickerMode.month => DatePickerMonthGrid(
          viewMonth: _viewMonth,
          onSelectMonth: _selectMonth,
        ),
        DuskDatePickerMode.year => DatePickerYearSelector(
          controller: _yearScrollController,
          minLoadedYear: _minLoadedYear,
          maxLoadedYear: _maxLoadedYear,
          selectedYear: _viewMonth.year,
          onSelectYear: _selectYear,
          onWidthMeasured: (w) => _lastItemWidth = w,
        ),
      },
    );
  }
}
