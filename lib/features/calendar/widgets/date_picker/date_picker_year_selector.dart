import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Scrollable year selector grid for DuskDatePickerDialog.
class DatePickerYearSelector extends StatelessWidget {
  final ScrollController controller;
  final int minLoadedYear;
  final int maxLoadedYear;
  final int selectedYear;
  final ValueChanged<int> onSelectYear;
  final ValueChanged<double>? onWidthMeasured;

  const DatePickerYearSelector({
    super.key = const ValueKey('year_picker'),
    required this.controller,
    required this.minLoadedYear,
    required this.maxLoadedYear,
    required this.selectedYear,
    required this.onSelectYear,
    this.onWidthMeasured,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = (constraints.maxWidth - 20.0).clamp(
          0.0,
          double.infinity,
        );
        final itemWidth = usableWidth / 3.0;
        if (onWidthMeasured != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onWidthMeasured!(itemWidth);
          });
        }

        final totalYears = maxLoadedYear - minLoadedYear + 1;

        return GridView.builder(
          controller: controller,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: 2.2,
          ),
          itemCount: totalYears,
          itemBuilder: (context, index) {
            final year = minLoadedYear + index;
            final isSelected = selectedYear == year;
            return _buildYearTile(year, isSelected);
          },
        );
      },
    );
  }

  Widget _buildYearTile(int year, bool isSelected) {
    return InkWell(
      onTap: () => onSelectYear(year),
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
  }
}
