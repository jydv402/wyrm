import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Slim tappable banner prompting the user to grant notification permission.
class ReminderPermissionBanner extends ConsumerWidget {
  const ReminderPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref
            .read(remindersProvider.notifier)
            .requestNotificationsPermission(),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: AppColors.plumAccent.withValues(alpha: 0.12),
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
                Icons.notifications_off_rounded,
                size: 14.0,
                color: AppColors.plumAccent,
              ),
              Expanded(
                child: Text(
                  'Notifications disabled - tap to allow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16.0,
                color: AppColors.plumAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
