import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Section 4: Web Remote Companion panel.
class NetworkSection extends ConsumerWidget {
  const NetworkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final server = ref.watch(webServerProvider);
    final serverPort = server.port ?? ShelfWebServer.defaultPort;
    final serverUrl = 'http://$ipAddress:$serverPort';

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsSectionHeader(
            icon: Icons.wifi_rounded,
            title: 'Web Remote Companion',
            subtitle: 'Control and sync Wyrm Desk wirelessly from any browser',
          ),
          const SizedBox(height: 18),
          _buildStatusBanner(context, ref, serverUrl),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    WidgetRef ref,
    String serverUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServerHeader(context, ref),
          const SizedBox(height: 10),
          _buildUrlBox(serverUrl),
        ],
      ),
    );
  }

  Widget _buildServerHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _buildIndicatorDot(),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Server Running',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        _buildQrButton(context, ref),
      ],
    );
  }

  Widget _buildIndicatorDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.glacierAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.glacierAccent,
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildQrButton(BuildContext context, WidgetRef ref) {
    return DuskGlassButton(
      onPressed: () => NetworkConnectionModal.show(context, ref),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      label: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_rounded, size: 16, color: AppColors.textPrimary),
          SizedBox(width: 6),
          Text(
            'Show QR',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlBox(String serverUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.link_rounded,
            size: 16,
            color: AppColors.glacierAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              serverUrl,
              style: const TextStyle(
                color: AppColors.glacierAccent,
                fontSize: 13.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
