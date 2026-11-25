import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/settings/settings_page.dart';
import 'package:wyrm_desk/features/update_checker/presentation/update_checker_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Section 6: App Updates panel.
class AppUpdatesSection extends ConsumerWidget {
  const AppUpdatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final isChecking = ref.watch(isCheckingUpdatesProvider);
    final versionStr = _resolveVersionString(packageInfoAsync);

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          const SettingsSectionHeader(
            icon: Icons.system_update_rounded,
            title: 'App Updates',
            subtitle: 'Version tracking and automated release alerts',
          ),
          const SizedBox(height: 6), // Originally was 18
          SettingRow(
            icon: Icons.info_outline_rounded,
            title: 'Current Version',
            subtitle: 'Wyrm Desk on ${settings.githubRepo}',
            trailing: _buildVersionBadge(versionStr),
          ),
          SettingRow(
            icon: Icons.update_rounded,
            title: 'Hourly Auto-Check',
            subtitle:
                'Silently checks for new releases in the background every hour',
            trailing: _buildAutoCheckSwitch(
              ref,
              settings.enableAutoUpdateChecks,
            ),
          ),
          SettingRow(
            icon: Icons.cloud_download_rounded,
            title: 'Check for Updates',
            subtitle: 'Manually fetch the latest GitHub release',
            trailing: _buildCheckButton(context, ref, isChecking),
          ),
        ],
      ),
    );
  }

  String _resolveVersionString(AsyncValue<PackageInfo> packageInfoAsync) {
    return packageInfoAsync.when(
      data: (info) => 'v${info.version}+${info.buildNumber}',
      loading: () => 'Loading...',
      error: (_, _) => 'v1.0.0+1',
    );
  }

  Widget _buildVersionBadge(String versionStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Text(
        versionStr,
        style: const TextStyle(
          color: AppColors.glacierAccent,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildAutoCheckSwitch(WidgetRef ref, bool enableAutoUpdateChecks) {
    return Switch.adaptive(
      value: enableAutoUpdateChecks,
      activeThumbColor: AppColors.glacierAccent,
      activeTrackColor: AppColors.glacierAccent.withValues(alpha: 0.35),
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.well,
      onChanged: (val) {
        ref.read(appSettingsProvider.notifier).setAutoUpdateChecks(val);
      },
    );
  }

  Widget _buildCheckButton(
    BuildContext context,
    WidgetRef ref,
    bool isChecking,
  ) {
    return DuskGlassButton(
      onPressed: isChecking
          ? null
          : () => ref.read(updateCheckerProvider.notifier).checkManual(context),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      label: isChecking ? _buildCheckingSpinner() : _buildCheckLabel(),
    );
  }

  Widget _buildCheckingSpinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.glacierAccent),
      ),
    );
  }

  Widget _buildCheckLabel() {
    return const Text(
      'Check Now',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
