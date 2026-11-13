import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';

/// Reusable form content for creating and editing calendar milestones in Dusk Glass style.
class MilestoneFormContent extends StatelessWidget {
  final TextEditingController titleController;
  final DateTime selectedDate;
  final bool isPinned;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<bool> onPinnedChanged;
  final VoidCallback? onChanged;

  const MilestoneFormContent({
    super.key,
    required this.titleController,
    required this.selectedDate,
    required this.isPinned,
    required this.onDateChanged,
    required this.onPinnedChanged,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Milestone Name',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        InAppKeyboardTextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Project Launch, Anniversary, Vacation',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.well,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line, width: 1.0),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide(color: AppColors.goldAccent, width: 1.5),
            ),
          ),
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 18),

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
          onTap: () async {
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
          },
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
                  '${monthNames[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}',
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
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.well,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line, width: 1.0),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.push_pin_rounded,
                size: 18,
                color: AppColors.goldAccent,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pin to Countdown Pill',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Highlights prominently at the top of the calendar card',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isPinned,
                activeThumbColor: AppColors.goldFill,
                inactiveThumbColor: AppColors.textSecondary,
                inactiveTrackColor: AppColors.well,
                onChanged: (val) {
                  onPinnedChanged(val);
                  onChanged?.call();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// WYSIWYG live preview card for calendar milestones.
class MilestonePreviewCard extends StatelessWidget {
  final String title;
  final DateTime targetDate;
  final bool isPinned;

  const MilestonePreviewCard({
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
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final days = targetMidnight.difference(todayMidnight).inDays;

    String daysLabel;
    if (days == 0) {
      daysLabel = 'Today';
    } else if (days == 1) {
      daysLabel = 'Tomorrow';
    } else if (days == -1) {
      daysLabel = 'Yesterday';
    } else if (days > 0) {
      daysLabel = 'In $days days';
    } else {
      daysLabel = '${days.abs()} days ago';
    }

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
          Row(
            children: [
              Container(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
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
                      '${monthNames[targetDate.month - 1]} ${targetDate.day}, ${targetDate.year}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line, width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: AppColors.goldAccent,
                      ),
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
                  ),
                ),
                if (isPinned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
