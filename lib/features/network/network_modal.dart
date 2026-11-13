import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Provider tracking whether the NetworkConnectionModal is currently open on the tablet.
final networkModalOpenProvider = NotifierProvider<NetworkModalNotifier, bool>(
  NetworkModalNotifier.new,
);

class NetworkModalNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool open) {
    if (state != open) state = open;
  }

  void toggle() {
    state = !state;
  }
}

/// Dusk Glass modal dialog displaying web remote URL and scannable QR code.
class NetworkConnectionModal extends ConsumerWidget {
  const NetworkConnectionModal({super.key});

  static bool _isOpen = false;
  static BuildContext? _dialogContext;

  /// Whether the connection modal is currently visible on screen.
  static bool get isOpen => _isOpen;

  /// Displays the connection modal.
  static Future<void> show(BuildContext context, [WidgetRef? ref]) async {
    if (_isOpen) return;
    _isOpen = true;
    ref?.read(networkModalOpenProvider.notifier).setOpen(true);
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (dialogCtx) {
          _dialogContext = dialogCtx;
          return const NetworkConnectionModal();
        },
      );
    } finally {
      _isOpen = false;
      _dialogContext = null;
      ref?.read(networkModalOpenProvider.notifier).setOpen(false);
    }
  }

  /// Closes the connection modal if currently open.
  static void hide([WidgetRef? ref]) {
    if (!_isOpen) return;
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pop();
    }
    _isOpen = false;
    _dialogContext = null;
    ref?.read(networkModalOpenProvider.notifier).setOpen(false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final server = ref.watch(webServerProvider);
    final serverPort = server.port ?? ShelfWebServer.defaultPort;
    final serverUrl = 'http://$ipAddress:$serverPort';

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.teal.accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.teal.accent.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.wifi_rounded,
                      color: AppColors.tealFill,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web Remote',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Connect from your phone or laptop',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DuskGlassButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    size: 32.0,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // QR Code in rounded well
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: serverUrl,
                    version: QrVersions.auto,
                    size: 190.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // URL copy bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.well,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        serverUrl,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DuskGlassButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: serverUrl));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied "$serverUrl" to clipboard'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.surfaceElevated,
                          ),
                        );
                      },
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      label: const Text(
                        'Copy',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Make sure your device is on the same local Wi-Fi.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
