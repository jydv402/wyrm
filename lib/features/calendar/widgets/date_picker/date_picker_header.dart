import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

enum DuskDatePickerMode { day, month, year }

/// Top header for DuskDatePickerDialog displaying selected date title,
/// month/year toggling chips, and month navigation chevrons.
class DatePickerHeader extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime viewMonth;
  final DuskDatePickerMode mode;
  final VoidCallback onToggleMonth;
  final VoidCallback onToggleYear;
  final ValueChanged<int>? onShiftMonth;
  final VoidCallback? onClose;

  const DatePickerHeader({
    super.key,
    required this.selectedDate,
    required this.viewMonth,
    required this.mode,
    required this.onToggleMonth,
    required this.onToggleYear,
    this.onShiftMonth,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitleRow(context),
        const SizedBox(height: 12),
        _buildControlsRow(),
      ],
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(selectedDate);

    return Row(
      spacing: 16,
      children: [
        const Icon(
          Icons.explore_rounded,
          size: 20,
          color: AppColors.goldAccent,
        ),
        _buildTitleColumn(dateStr),
        const Spacer(),
        _buildCloseButton(context),
      ],
    );
  }

  Widget _buildTitleColumn(String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Time Travel',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateStr,
          style: const TextStyle(
            color: AppColors.goldAccent,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return DuskGlassButton.icon(
      onPressed: onClose ?? () => context.pop(null),
      icon: const Icon(Icons.close_rounded, size: 20),
      size: 38,
    );
  }

  Widget _buildControlsRow() {
    return Row(
      children: [
        Flexible(child: _buildMonthChip()),
        const SizedBox(width: 8),
        _buildYearChip(),
        const Spacer(),
        if (mode == DuskDatePickerMode.day) _buildChevrons(),
      ],
    );
  }

  Widget _buildMonthChip() {
    final currentMonthName =
        monthNames[(viewMonth.month - 1).clamp(0, monthNames.length - 1)];
    return _buildSelectorChip(
      label: currentMonthName,
      isActive: mode == DuskDatePickerMode.month,
      onTap: onToggleMonth,
    );
  }

  Widget _buildYearChip() {
    return _buildSelectorChip(
      label: '${viewMonth.year}',
      isActive: mode == DuskDatePickerMode.year,
      onTap: onToggleYear,
    );
  }

  Widget _buildSelectorChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.goldFill : AppColors.well,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.transparent : AppColors.line,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? AppColors.goldInk : AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
              size: 18,
              color: isActive ? AppColors.goldInk : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChevrons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DuskGlassButton.icon(
          onPressed: () => onShiftMonth?.call(-1),
          size: 32,
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        DuskGlassButton.icon(
          onPressed: () => onShiftMonth?.call(1),
          size: 32,
          icon: const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
