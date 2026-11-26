import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/reminder_format.dart';
import 'package:wyrm_desk/features/reminder/widgets/form/reminder_form_section.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// One-time reminder date picker (Today / Tomorrow / calendar picker).
class ReminderDateSelector extends StatelessWidget {
  /// Current wall-clock instant.
  final DateTime now;

  /// Resolved target instant for the current selections.
  final DateTime scheduledAt;

  /// Whether [scheduledAt] was auto-wrapped from today to tomorrow.
  final bool autoWrappedToTomorrow;

  /// Called with the newly chosen calendar day.
  final ValueChanged<DateTime> onDateChanged;

  /// Called after the user picks a day from the date picker dialog.
  final VoidCallback? onChanged;

  const ReminderDateSelector({
    super.key,
    required this.now,
    required this.scheduledAt,
    required this.autoWrappedToTomorrow,
    required this.onDateChanged,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final effectiveDay = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    );
    final isTodaySelected = !autoWrappedToTomorrow && effectiveDay == today;
    final isTomorrowSelected = effectiveDay == tomorrow;
    final isCustomDay = !isTodaySelected && !isTomorrowSelected;

    return ReminderFormSection(
      label: 'Target Date',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8.0,
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _DatePill(
                key: const ValueKey<String>('reminder_date_today'),
                label: 'Today',
                isSelected: isTodaySelected,
                onTap: () => onDateChanged(today),
              ),
              _DatePill(
                key: const ValueKey<String>('reminder_date_tomorrow'),
                label: 'Tomorrow',
                isSelected: isTomorrowSelected,
                onTap: () => onDateChanged(tomorrow),
              ),
              DuskGlassPill(
                key: const ValueKey<String>('reminder_date_pick'),
                onTap: () => _pickDate(context, today),
                tintColor: isCustomDay
                    ? AppColors.plumAccent
                    : AppColors.textSecondary,
                height: 34.0,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                icon: const Icon(
                  Icons.event_rounded,
                  size: 14.0,
                  color: AppColors.plumAccent,
                ),
                child: Text(
                  isCustomDay
                      ? formatReminderDayLabel(effectiveDay, now)
                      : 'Pick Date',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (autoWrappedToTomorrow) const _AutoWrapNotice(),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime today) async {
    final initial = scheduledAt.isBefore(today) ? today : scheduledAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.plumFill,
              onPrimary: AppColors.plumInk,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    onDateChanged(DateTime(picked.year, picked.month, picked.day));
    onChanged?.call();
  }
}

class _DatePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DatePill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DuskGlassPill(
      onTap: onTap,
      tintColor: isSelected ? AppColors.plumAccent : AppColors.textSecondary,
      height: 34.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AutoWrapNotice extends StatelessWidget {
  const _AutoWrapNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.plumAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.plumAccent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: const Row(
        spacing: 8.0,
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 15.0,
            color: AppColors.plumAccent,
          ),
          Expanded(
            child: Text(
              'Time passed today - auto-scheduled for Tomorrow',
              style: TextStyle(
                color: AppColors.plumAccent,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
