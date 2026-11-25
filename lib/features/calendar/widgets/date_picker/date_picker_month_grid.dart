import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// 12-month grid selector for DuskDatePickerDialog.
class DatePickerMonthGrid extends StatelessWidget {
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

  final DateTime viewMonth;
  final ValueChanged<int> onSelectMonth;

  const DatePickerMonthGrid({
    super.key = const ValueKey('month_picker'),
    required this.viewMonth,
    required this.onSelectMonth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 24) / 3;
        final itemHeight = (constraints.maxHeight - 36) / 4;
        final ratio = (itemWidth / itemHeight).clamp(1.2, 3.2);

        return GridView.builder(
          key: key,
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: itemWidth > 180 ? 4 : 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: ratio,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final monthNumber = index + 1;
            final isSelected = viewMonth.month == monthNumber;
            return _buildMonthTile(index, monthNumber, isSelected);
          },
        );
      },
    );
  }

  Widget _buildMonthTile(int index, int monthNumber, bool isSelected) {
    return InkWell(
      onTap: () => onSelectMonth(monthNumber),
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
  }
}
