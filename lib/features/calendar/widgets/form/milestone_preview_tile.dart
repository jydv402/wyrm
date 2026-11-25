import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Alias for backwards compatibility with tests and existing imports.
typedef MilestonePreviewCard = MilestonePreviewTile;

/// WYSIWYG live preview tile/card for calendar milestones.
class MilestonePreviewTile extends StatelessWidget {
  final String title;
  final DateTime targetDate;
  final bool isPinned;

  const MilestonePreviewTile({
    super.key,
    required this.title,
    required this.targetDate,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.trim().isEmpty
        ? 'Milestone Title'
        : title.trim();
    final monthName = monthNames[targetDate.month - 1];
    final formattedDate = '$monthName ${targetDate.day}, ${targetDate.year}';
    final daysLabel = _computeDaysLabel(targetDate);

    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lineStrong, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(displayTitle, formattedDate),
          const SizedBox(height: 14),
          _buildCountdownBar(daysLabel),
        ],
      ),
    );
  }

  Widget _buildHeader(String displayTitle, String formattedDate) {
    return Row(
      children: [
        _buildHeaderIcon(),
        const SizedBox(width: 10),
        Expanded(child: _buildHeaderText(displayTitle, formattedDate)),
      ],
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.goldAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isPinned ? Icons.push_pin_rounded : Icons.event_rounded,
        size: 20,
        color: AppColors.goldAccent,
      ),
    );
  }

  Widget _buildHeaderText(String displayTitle, String formattedDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          formattedDate,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownBar(String daysLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildDaysSection(daysLabel)),
          if (isPinned) _buildPinnedBadge(),
        ],
      ),
    );
  }

  Widget _buildDaysSection(String daysLabel) {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 16, color: AppColors.goldAccent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            daysLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.goldAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.goldAccent.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: const Text(
        'PINNED',
        style: TextStyle(
          color: AppColors.goldAccent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String _computeDaysLabel(DateTime target) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(target.year, target.month, target.day);
    final days = targetMidnight.difference(todayMidnight).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days > 0) return 'In $days days';
    return '${days.abs()} days ago';
  }
}
