import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Compact next-up body: time, countdown pill, and one-line title.
class CompactNextUpContent extends StatelessWidget {
  /// Formatted next fire time.
  final String timeLabel;

  /// Relative countdown label.
  final String countdown;

  /// Reminder title.
  final String title;

  const CompactNextUpContent({
    super.key,
    required this.timeLabel,
    required this.countdown,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4.0,
      children: [
        Row(
          spacing: 6.0,
          children: [
            const Icon(
              Icons.alarm_rounded,
              size: 14.0,
              color: AppColors.plumAccent,
            ),
            Text(
              timeLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.0,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Flexible(
              child: DuskGlassPill(
                tintColor: AppColors.plumAccent,
                height: 22.0,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  countdown,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Full next-up body: NEXT UP header, recurrence pill, time, countdown, title.
class HeroNextUpContent extends StatelessWidget {
  /// Formatted next fire time.
  final String timeLabel;

  /// Relative countdown label.
  final String countdown;

  /// Reminder title.
  final String title;

  /// Recurrence summary shown in the header pill.
  final String recurrenceLabel;

  /// Whether the upcoming occurrence is a snooze.
  final bool isSnoozed;

  const HeroNextUpContent({
    super.key,
    required this.timeLabel,
    required this.countdown,
    required this.title,
    required this.recurrenceLabel,
    required this.isSnoozed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        Row(
          spacing: 8.0,
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              size: 15.0,
              color: AppColors.plumAccent,
            ),
            const Text(
              'NEXT UP',
              style: TextStyle(
                color: AppColors.plumAccent,
                fontSize: 11.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            DuskGlassPill(
              tintColor: AppColors.plumAccent,
              height: 24.0,
              padding: const EdgeInsets.symmetric(horizontal: 9.0),
              child: Text(
                recurrenceLabel,
                style: const TextStyle(
                  color: AppColors.plumAccent,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10.0,
          runSpacing: 6.0,
          children: [
            Text(
              timeLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26.0,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            DuskGlassPill(
              tintColor: isSnoozed
                  ? AppColors.accentOrange
                  : AppColors.plumFill,
              height: 26.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Text(
                countdown,
                style: TextStyle(
                  color: isSnoozed
                      ? AppColors.accentOrange
                      : AppColors.plumAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Placeholder strip shown when no future occurrence exists.
class EmptyNextUpStrip extends StatelessWidget {
  /// Whether the store contains reminders (all of them paused/inactive).
  final bool hasAnyReminders;

  /// Whether the host card uses the compact layout.
  final bool compact;

  const EmptyNextUpStrip({
    super.key,
    required this.hasAnyReminders,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12.0 : 14.0,
        vertical: compact ? 8.0 : 12.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(compact ? 14.0 : 18.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 8.0,
        children: [
          const Icon(
            Icons.notifications_paused_rounded,
            size: 16.0,
            color: AppColors.textMuted,
          ),
          Expanded(
            child: Text(
              hasAnyReminders ? 'All reminders paused' : 'No upcoming alarms',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
