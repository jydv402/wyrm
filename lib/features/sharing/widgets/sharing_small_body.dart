import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/sharing/sharing_mime.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_permission_gate.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_qr_dialog.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Compact summary body for [SharingCard] when rendered in [CardSize.small].
class SharingSmallBody extends ConsumerWidget {
  /// Creates a [SharingSmallBody].
  const SharingSmallBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(
      sharingProvider.select((s) => s.hasPermission),
    );
    if (!hasPermission) {
      return const SharingPermissionGate(isCompact: true);
    }

    final summary = ref.watch(
      sharingProvider.select(
        (s) => (
          files: s.fileCount,
          folders: s.folderCount,
          bytes: s.totalBytes,
          password: s.passwordDisplay,
        ),
      ),
    );

    final ip = ref.watch(localIpProvider).value ?? '127.0.0.1';
    final port =
        ref.watch(webServerProvider.select((s) => s.port)) ??
        ShelfWebServer.defaultPort;
    final webUrl = 'http://$ip:$port';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 14.0,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4.0,
            children: [
              Text(
                '${summary.files} ${summary.files == 1 ? 'file' : 'files'} · '
                '${summary.folders} ${summary.folders == 1 ? 'folder' : 'folders'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                SharingMime.formatByteSize(summary.bytes),
                style: const TextStyle(
                  color: AppColors.cobaltAccent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                webUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8.0,
            children: [
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: summary.password));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sharing password copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 10.0,
                    vertical: 7.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.well,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: AppColors.cobaltAccent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.key_rounded,
                        size: 14.0,
                        color: AppColors.cobaltAccent,
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          summary.password,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.copy_rounded,
                        size: 13.0,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              DuskGlassButton(
                key: const ValueKey<String>('sharing_small_qr_button'),
                onPressed: () {
                  SharingQrDialog.show(
                    context,
                    title: 'Web Remote Sharing',
                    subtitle:
                        'Scan to upload or download files over local Wi-Fi.',
                    url: webUrl,
                    passwordHint: summary.password,
                  );
                },
                height: 34.0,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12.0,
                ),
                icon: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 16.0,
                  color: AppColors.cobaltAccent,
                ),
                label: const Text(
                  'Web QR',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
