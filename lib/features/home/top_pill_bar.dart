import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/features/settings/settings_page.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
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
        children: [
          // WYRM. Brand Logo Mark
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/header_text.svg',
                height: 14.0,
                colorFilter: const ColorFilter.mode(
                  AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(left: 3, top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.brandDot,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),

          const SizedBox(width: 18),

          // Vertical divider line
          Container(width: 1.0, height: 18.0, color: AppColors.lineStrong),

          const SizedBox(width: 18),

          // Ambient Tagline
          const Expanded(
            child: Text(
              'A calmer, more focused you',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Center/Right Network Status Pill
          child ?? const _ServerNetworkPill(),

          const SizedBox(width: 10),

          // Settings Gear Action Button
          DuskGlassButton.icon(
            onPressed: onOpenSettings ?? () => SettingsPage.open(context),
            size: 40.0,
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
