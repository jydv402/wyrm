import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/reminder_filter.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Row of filter pills switching the reminder list between All/Active/Recurring.
class ReminderFilterPills extends ConsumerWidget {
  /// Currently selected filter.
  final ReminderFilter selected;

  const ReminderFilterPills({super.key, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        for (final filter in ReminderFilter.values)
          DuskGlassPill(
            key: ValueKey<String>('reminder_filter_${filter.name}'),
            onTap: () => ref.read(remindersProvider.notifier).setFilter(filter),
            tintColor: selected == filter
                ? AppColors.plumAccent
                : AppColors.textSecondary,
            height: 34.0,
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Text(
              filter.label,
              style: TextStyle(
                color: selected == filter
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: selected == filter
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
