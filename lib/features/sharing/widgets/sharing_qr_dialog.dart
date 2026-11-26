import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Modal displaying a scannable QR code for the Web Remote Sharing view or a
/// tokenized one-tap file download URL.
class SharingQrDialog extends StatefulWidget {
  /// Modal heading (e.g. `Web Remote Sharing` or the file name).
  final String title;

  /// Short guidance line shown beneath the QR frame.
  final String subtitle;

  /// Full LAN URL encoded inside the QR image.
  final String url;

  /// Optional sharing password badge displayed alongside the Web Remote URL.
  final String? passwordHint;

  /// Creates a [SharingQrDialog].
  const SharingQrDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.url,
    this.passwordHint,
  });

  /// Shows [SharingQrDialog] as a barrier-dismissible Dusk Glass modal.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String url,
    String? passwordHint,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => SharingQrDialog(
        title: title,
        subtitle: subtitle,
        url: url,
        passwordHint: passwordHint,
      ),
    );
  }

  @override
  State<SharingQrDialog> createState() => _SharingQrDialogState();
}

class _SharingQrDialogState extends State<SharingQrDialog> {
  bool _hasCopied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.url));
    HapticFeedback.lightImpact();
    _resetTimer?.cancel();
    setState(() => _hasCopied = true);
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hasCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final password = widget.passwordHint;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360.0),
        child: DuskGlassPanel(
          tone: AppColors.cobalt,
          borderRadius: 28.0,
          padding: const EdgeInsetsDirectional.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14.0,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    color: AppColors.cobaltAccent,
                    size: 22.0,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20.0,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsetsDirectional.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: QrImageView(
                  data: widget.url,
                  version: QrVersions.auto,
                  size: 196.0,
                  backgroundColor: Colors.white,
                ),
              ),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              if (password != null && password.isNotEmpty)
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.well,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: AppColors.cobaltAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Password: $password',
                    style: const TextStyle(
                      color: AppColors.cobaltAccent,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              DuskGlassButton(
                onPressed: _copyUrl,
                height: 38.0,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16.0,
                ),
                icon: Icon(
                  _hasCopied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16.0,
                  color: AppColors.cobaltAccent,
                ),
                label: Text(
                  _hasCopied ? 'Link Copied' : 'Copy Link',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
