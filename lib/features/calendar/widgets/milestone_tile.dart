import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/calendar/calendar_model.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Single Dusk Glass milestone row with countdown label and delete action.
class MilestoneTile extends ConsumerWidget {
  final CalendarMilestone milestone;

  const MilestoneTile({super.key, required this.milestone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedDate = DateFormat('MMM d, yyyy')
        .format(milestone.targetDate);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 10),
          Expanded(child: _buildDetails(formattedDate)),
          Text(
            milestone.relativeLabel,
            style: const TextStyle(
              color: AppColors.goldAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          _buildDeleteButton(ref),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.goldAccent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.flag_rounded,
        size: 16,
        color: AppColors.goldAccent,
      ),
    );
  }

  Widget _buildDetails(String formattedDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          milestone.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formattedDate,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(WidgetRef ref) {
    return DuskGlassButton.icon(
      onPressed: () =>
          ref.read(calendarProvider.notifier).deleteMilestone(milestone.id),
      icon: const Icon(
        Icons.close_rounded,
        size: 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}
