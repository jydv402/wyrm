import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Card summarizing notification and exact-alarm permission status.
class ReminderPermissionStatusCard extends ConsumerWidget {
  /// Permission flags to render.
  final NotificationPermissionStatus permissions;

  const ReminderPermissionStatusCard({super.key, required this.permissions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsEnabled = permissions.notificationsEnabled;
    final exactAlarmsAllowed = permissions.exactAlarmsAllowed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 10.0,
        children: [
          Icon(
            notificationsEnabled
                ? Icons.verified_user_rounded
                : Icons.notifications_off_rounded,
            size: 18.0,
            color: notificationsEnabled
                ? AppColors.plumAccent
                : AppColors.accentOrange,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.0,
              children: [
                Text(
                  notificationsEnabled
                      ? 'Notifications allowed'
                      : 'Notifications off',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  exactAlarmsAllowed
                      ? 'Precise timing active'
                      : 'Inexact background timing',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          if (!notificationsEnabled)
            DuskGlassButton(
              onPressed: () => ref
                  .read(remindersProvider.notifier)
                  .requestNotificationsPermission(),
              height: 32.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              label: const Text(
                'Enable',
                style: TextStyle(
                  color: AppColors.textPrimary,
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
