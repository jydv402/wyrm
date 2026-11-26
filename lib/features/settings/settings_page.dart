import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_ambient_backdrop.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_content_pane.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_top_bar.dart';
import 'package:wyrm_desk/theme/theme.dart';

export 'widgets/app_updates_section.dart';
export 'widgets/appearance_section.dart';
export 'widgets/clock_calendar_section.dart';
export 'widgets/data_backup_section.dart';
export 'widgets/display_section.dart';
export 'widgets/network_section.dart';
export 'widgets/reminders_section.dart';
export 'widgets/setting_row.dart';
export 'widgets/sharing_section.dart';
export 'widgets/settings_ambient_backdrop.dart';
export 'widgets/settings_content_pane.dart';
export 'widgets/settings_section_header.dart';
export 'widgets/settings_top_bar.dart';

/// Provider exposing platform package version information.
final packageInfoProvider = FutureProvider.autoDispose<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Fullscreen Dusk Glass settings page for Wyrm Desk.
///
/// Clean, unified fullscreen view presenting all application preferences,
/// display controls, time/calendar conventions, and web companion status
/// with responsive layout and atmospheric ambient backdrops.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Opens the settings page using GoRouter.
  static Future<void> open(BuildContext context) {
    return context.push<void>(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: SettingsAmbientBackdrop()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16.0,
                children: [const SettingsTopBar(), _buildContentPane()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPane() {
    return Expanded(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: const SettingsContentPane(),
        ),
      ),
    );
  }
}
