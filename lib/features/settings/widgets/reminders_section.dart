import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/settings/widgets/setting_row.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Settings panel for reminder notification permissions, exact alarm timing,
/// and live full-screen alarm overlay previewing.
class RemindersSection extends ConsumerWidget {
  const RemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(
      remindersProvider.select((state) => state.permissions),
    );
    final notificationsEnabled = permissions.notificationsEnabled;
    final exactAlarmsAllowed = permissions.exactAlarmsAllowed;

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          const SettingsSectionHeader(
            icon: Icons.notifications_active_rounded,
            title: 'Reminders & Alarms',
            subtitle: 'Background notification permissions, timing precision, and alarm preview',
          ),
          const SizedBox(height: 6),
          SettingRow(
            icon: Icons.notifications_rounded,
            title: 'Allow Notifications',
            subtitle: notificationsEnabled
                ? 'Granted — reminders can wake and display full-screen alerts'
                : 'Required to deliver scheduled reminders in the background',
            trailing: _PermissionActionTrailing(
              isGranted: notificationsEnabled,
              grantedLabel: 'Allowed',
              pendingLabel: 'Needed',
              buttonLabel: notificationsEnabled ? 'Settings' : 'Allow',
              onPressed: () {
                final notifier = ref.read(remindersProvider.notifier);
                if (notificationsEnabled) {
                  notifier.openSystemNotificationSettings();
                } else {
                  notifier.requestNotificationsPermission();
                }
              },
            ),
          ),
          SettingRow(
            icon: Icons.alarm_on_rounded,
            title: 'Precise Background Timing',
            subtitle: exactAlarmsAllowed
                ? 'Exact alarms enabled for on-the-minute delivery'
                : 'Allow exact alarm scheduling so reminders ring on the minute',
            trailing: _PermissionActionTrailing(
              isGranted: exactAlarmsAllowed,
              grantedLabel: 'Exact',
              pendingLabel: 'Inexact',
              buttonLabel: exactAlarmsAllowed ? 'Settings' : 'Enable',
              onPressed: () {
                final notifier = ref.read(remindersProvider.notifier);
                if (exactAlarmsAllowed) {
                  notifier.openSystemNotificationSettings();
                } else {
                  notifier.requestExactAlarmsPermission();
                }
              },
            ),
          ),
          SettingRow(
            icon: Icons.fullscreen_rounded,
            title: 'Preview Alarm Screen',
            subtitle: 'Test the full-screen alarm overlay and chime without changing saved reminders',
            trailing: DuskGlassButton(
              key: const ValueKey<String>('settings_preview_alarm_button'),
              onPressed: () => _triggerPreviewAlarm(ref),
              height: 38.0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              icon: const Icon(
                Icons.notifications_active_rounded,
                size: 16.0,
                color: AppColors.glacierAccent,
              ),
              label: const Text(
                'Preview',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerPreviewAlarm(WidgetRef ref) {
    final now = ref.read(clockProvider).now();
    ref
        .read(activeAlarmProvider.notifier)
        .triggerAlarm(
          ReminderItem(
            id: 'preview_alarm',
            title: 'Preview Alarm',
            scheduledAt: now,
            recurrence: ReminderRecurrence.once,
            isEnabled: true,
            createdAt: now,
          ),
          now,
          isPreview: true,
        );
  }
}

class _PermissionActionTrailing extends StatelessWidget {
  final bool isGranted;
  final String grantedLabel;
  final String pendingLabel;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _PermissionActionTrailing({
    required this.isGranted,
    required this.grantedLabel,
    required this.pendingLabel,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isGranted
        ? AppColors.glacierAccent
        : AppColors.accentOrange;

    return Wrap(
      spacing: 8.0,
      runSpacing: 6.0,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DuskGlassPill(
          tintColor: statusColor,
          height: 30.0,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Text(
            isGranted ? grantedLabel : pendingLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DuskGlassButton(
          onPressed: onPressed,
          height: 38.0,
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          label: Text(
            buttonLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
