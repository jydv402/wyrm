import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
///
/// Faithfully reproduces the visual design, backdrop blur, triple glow halo,
/// and interactive address pill from the Web Remote's NetworkModal component.
class NetworkConnectionModal extends ConsumerStatefulWidget {
  const NetworkConnectionModal({super.key});

  static bool _isOpen = false;
  static BuildContext? _dialogContext;

  /// Whether the connection modal is currently visible on screen.
  static bool get isOpen => _isOpen;

  /// Displays the connection modal with frosted backdrop blur and pop-in animation.
  static Future<void> show(BuildContext context, [WidgetRef? ref]) async {
    if (_isOpen) return;
    _isOpen = true;
    ref?.read(networkModalOpenProvider.notifier).setOpen(true);
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Web remote',
        barrierColor: Colors.black.withValues(alpha: 0.72),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogCtx, animation, secondaryAnimation) {
          _dialogContext = dialogCtx;
          return const NetworkConnectionModal();
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: Transform.translate(
              offset: Offset(0, 10 * (1.0 - curve.value)),
              child: Transform.scale(
                scale: 0.97 + (0.03 * curve.value),
                child: child,
              ),
            ),
          );
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
      _dialogContext!.pop();
    }
    _isOpen = false;
    _dialogContext = null;
    ref?.read(networkModalOpenProvider.notifier).setOpen(false);
  }

  @override
  ConsumerState<NetworkConnectionModal> createState() =>
      _NetworkConnectionModalState();
}

class _NetworkConnectionModalState
    extends ConsumerState<NetworkConnectionModal> {
  bool _isCopied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.lightImpact();
    _copyTimer?.cancel();
    setState(() => _isCopied = true);
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final server = ref.watch(webServerProvider);
    final serverPort = server.port ?? ShelfWebServer.defaultPort;
    final serverUrl = 'http://$ipAddress:$serverPort';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1B2223), Color(0xFF131718)],
                  ),
                  borderRadius: BorderRadius.circular(34.0),
                  border: Border.all(
                    color: AppColors.teal.accent.withValues(alpha: 0.22),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.75),
                      blurRadius: 48.0,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildQrSection(serverUrl),
                    const SizedBox(height: 20),
                    _buildAddressBar(serverUrl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_rounded, color: AppColors.tealFill, size: 24),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Web remote',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Connect from your phone or laptop',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        DuskGlassButton.icon(
          onPressed: () => context.pop(),
          size: 36.0,
          icon: const Icon(
            Icons.close_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQrSection(String serverUrl) {
    return Column(
      children: [
        Container(
          width: 232.0,
          height: 232.0,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.accent.withValues(alpha: 0.40),
                blurRadius: 0,
                spreadRadius: 1.0,
              ),
              BoxShadow(
                color: AppColors.teal.accent.withValues(alpha: 0.09),
                blurRadius: 0,
                spreadRadius: 10.0,
              ),
              BoxShadow(
                color: AppColors.teal.accent.withValues(alpha: 0.55),
                blurRadius: 44.0,
                spreadRadius: -20.0,
                offset: const Offset(0, 26),
              ),
            ],
          ),
          child: Center(
            child: QrImageView(
              data: serverUrl,
              version: QrVersions.auto,
              size: 204.0,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260.0),
          child: const Text(
            'Point your phone camera at the code to open Wyrm Desk in your browser.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.0,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressBar(String serverUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
                Text(
                  serverUrl,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DuskGlassButton(
            onPressed: () => _copyUrl(serverUrl),
            height: 36,
            isPrimary: _isCopied,
            primaryColor: AppColors.tealFill,
            primaryForegroundColor: AppColors.tealInk,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: 999.0,
            icon: Icon(
              _isCopied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
              color: _isCopied ? AppColors.tealInk : AppColors.textPrimary,
            ),
            label: Text(
              _isCopied ? 'Copied' : 'Copy',
              style: TextStyle(
                color: _isCopied ? AppColors.tealInk : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: _isCopied ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
