import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/battery/battery_pill.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/features/settings/settings_page.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Pinned top navigation and status pill bar matching the Dusk Glass screenshot.
class TopPillBar extends StatelessWidget {
  final double height;
  final Widget? child;
  final VoidCallback? onOpenSettings;

  const TopPillBar({
    super.key,
    this.height = 54.0,
    this.child,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 18.0, right: 8.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.lineStrong, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          // WYRM. Brand Logo Mark
          SvgPicture.asset('assets/icons/header_text.svg', height: 24.0),

          const Spacer(),

          // Battery Status Pill
          const BatteryPill(),

          // Center/Right Network Status Pill
          child ?? const _ServerNetworkPill(),

          // Settings Gear Action Button
          DuskGlassButton.icon(
            onPressed: onOpenSettings ?? () => SettingsPage.open(context),
            icon: const Icon(
              Icons.settings_rounded,
              size: 19,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Always-visible network pill displaying active server IP and opening connection modal.
class _ServerNetworkPill extends ConsumerWidget {
  const _ServerNetworkPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final server = ref.watch(webServerProvider);
    final serverPort = server.port ?? ShelfWebServer.defaultPort;
    final serverUrl = '$ipAddress:$serverPort';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => NetworkConnectionModal.show(context, ref),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.lineStrong, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_rounded,
                size: 17,
                color: AppColors.tealAccent,
              ),
              const SizedBox(width: 10),
              Text(
                serverUrl,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
