import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/server/network_info.dart';
import 'package:wyrm_desk/settings/settings.dart';

import 'bento_box.dart';

/// Top horizontal pill bar container hosting ambient brand header, status, and settings access.
class TopPillBar extends StatelessWidget {
  /// Total height of the top bar container.
  final double height;

  /// Custom center content overriding default server network pill.
  final Widget? child;

  /// Optional callback overriding default settings dialog presentation.
  final VoidCallback? onOpenSettings;

  const TopPillBar({
    super.key,
    this.height = 54.0,
    this.child,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return BentoBox(
      height: height,
      color: AppColors.cardCream,
      borderRadius: height / 2,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        spacing: 8,
        children: [
          // Left ambient brand SVG logo mark.
          SvgPicture.asset(
            'assets/icons/header_text.svg',
            height: 24,
            colorFilter: const ColorFilter.mode(
              AppColors.textOnLight,
              BlendMode.srcIn,
            ),
          ),

          Spacer(),

          child ?? const _ServerNetworkPill(),

          // Settings action button triggering the bento configuration modal.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenSettings ?? () => SettingsDialog.show(context),
              borderRadius: BorderRadius.circular(height / 2),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  size: 18,
                  color: AppColors.textOnLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal always-visible network pill displaying the active server IP address and status.
class _ServerNetworkPill extends ConsumerWidget {
  const _ServerNetworkPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final serverUrl = 'http://$ipAddress:8080';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: serverUrl));
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "$serverUrl" to clipboard'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.cardCream,
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '$ipAddress:8080',
            style: const TextStyle(
              color: AppColors.textOnLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
