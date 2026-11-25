import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Target date selection row for milestone creation and editing.
class MilestoneDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback? onChanged;

  const MilestoneDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.onChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.goldFill,
              onPrimary: AppColors.goldInk,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
      onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = monthNames[selectedDate.month - 1];
    final dateText = '$monthName ${selectedDate.day}, ${selectedDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Target Date',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickDate(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.0),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 18,
                  color: AppColors.goldAccent,
                ),
                const SizedBox(width: 10),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Change',
                  style: TextStyle(
                    color: AppColors.goldAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
