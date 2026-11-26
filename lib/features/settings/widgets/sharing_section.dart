import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/settings/widgets/setting_row.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_text_prompt_dialog.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Settings panel for `@sharing/` storage permission, Unified Shared Folder
/// root path, device-wide browse scope, and Web Remote sharing password.
class SharingSection extends ConsumerWidget {
  /// Creates a [SharingSection].
  const SharingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharingMeta = ref.watch(
      sharingProvider.select(
        (s) => (
          hasPermission: s.hasPermission,
          password: s.passwordDisplay,
          isCustomPassword: s.isCustomPassword,
        ),
      ),
    );
    final rootPath = ref.watch(
      appSettingsProvider.select((s) => s.sharingRootPath),
    );
    final allowDeviceBrowse = ref.watch(
      appSettingsProvider.select((s) => s.sharingAllowDeviceBrowse),
    );

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsetsDirectional.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          const SettingsSectionHeader(
            icon: Icons.swap_horiz_rounded,
            title: 'Local File Sharing',
            subtitle: 'All Files Access permission, shared folder scope, and LAN password',
          ),
          const SizedBox(height: 6.0),
          SettingRow(
            icon: Icons.folder_shared_rounded,
            title: 'All Files Access',
            subtitle: sharingMeta.hasPermission
                ? 'Granted - tablet can store, browse, and relay shared files'
                : 'Required on Android to read and write the shared folder',
            trailing: _AccessStatusTrailing(
              isGranted: sharingMeta.hasPermission,
              onPressed: () {
                final notifier = ref.read(sharingProvider.notifier);
                if (sharingMeta.hasPermission) {
                  notifier.refreshPermissionAndDirectory();
                } else {
                  notifier.requestPermission();
                }
              },
            ),
          ),
          SettingRow(
            icon: Icons.drive_folder_upload_rounded,
            title: 'Unified Shared Folder',
            subtitle: rootPath,
            trailing: Wrap(
              spacing: 8.0,
              children: [
                DuskGlassButton(
                  onPressed: () async {
                    final nextPath = await SharingTextPromptDialog.show(
                      context,
                      title: 'Shared Folder Path',
                      hintText: AppSettingsConfig.defaultSharingRootPath,
                      confirmLabel: 'Save',
                      initialValue: rootPath,
                    );
                    if (nextPath == null) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .setSharingRootPath(nextPath);
                  },
                  height: 36.0,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (rootPath != AppSettingsConfig.defaultSharingRootPath)
                  DuskGlassButton(
                    onPressed: () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setSharingRootPath(
                            AppSettingsConfig.defaultSharingRootPath,
                          );
                    },
                    height: 36.0,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12.0,
                    ),
                    label: const Text(
                      'Reset',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SettingRow(
            icon: Icons.sd_storage_rounded,
            title: 'Browse Full Device Storage',
            subtitle: allowDeviceBrowse
                ? 'Web Remote & tablet browser can navigate /storage/emulated/0'
                : 'Scoped strictly to the Unified Shared Folder',
            trailing: Switch(
              value: allowDeviceBrowse,
              activeThumbColor: AppColors.glacierAccent,
              onChanged: (value) {
                ref
                    .read(appSettingsProvider.notifier)
                    .setSharingAllowDeviceBrowse(value);
              },
            ),
          ),
          SettingRow(
            icon: Icons.key_rounded,
            title: 'Sharing Password',
            subtitle: sharingMeta.isCustomPassword
                ? 'Custom password: ${sharingMeta.password}'
                : 'Auto-generated 6-char code: ${sharingMeta.password}',
            trailing: Wrap(
              spacing: 8.0,
              children: [
                DuskGlassButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: sharingMeta.password),
                    );
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sharing password copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  height: 36.0,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 15.0,
                    color: AppColors.glacierAccent,
                  ),
                  label: const Text(
                    'Copy',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                DuskGlassButton(
                  onPressed: () {
                    ref.read(sharingProvider.notifier).regeneratePassword();
                  },
                  height: 36.0,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                  ),
                  label: const Text(
                    'New Code',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                DuskGlassButton(
                  onPressed: () async {
                    final nextPassword = await SharingTextPromptDialog.show(
                      context,
                      title: 'Custom Sharing Password',
                      hintText: 'Leave blank to use auto-generated 6-char code',
                      confirmLabel: 'Apply',
                      initialValue: sharingMeta.isCustomPassword
                          ? sharingMeta.password
                          : '',
                      allowEmpty: true,
                    );
                    if (nextPassword == null) return;
                    ref
                        .read(sharingProvider.notifier)
                        .setCustomPassword(nextPassword);
                  },
                  height: 36.0,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                  ),
                  label: const Text(
                    'Set',
                    style: TextStyle(
                      color: AppColors.glacierAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

class _AccessStatusTrailing extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onPressed;

  const _AccessStatusTrailing({
    required this.isGranted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DuskGlassPill(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10.0,
            vertical: 5.0,
          ),
          tintColor: isGranted ? AppColors.priorityLow : AppColors.accentOrange,
          child: Text(
            isGranted ? 'Allowed' : 'Needed',
            style: TextStyle(
              color: isGranted ? AppColors.priorityLow : AppColors.accentOrange,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DuskGlassButton(
          onPressed: onPressed,
          height: 36.0,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14.0),
          label: Text(
            isGranted ? 'Recheck' : 'Grant',
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
