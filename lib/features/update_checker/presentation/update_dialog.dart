import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wyrm_desk/features/update_checker/models/update_info.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Dusk Glass modal dialog presenting available application updates or up-to-date status.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  /// Displays the UpdateDialog as a modal route.
  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  Future<void> _launchDownloadUrl(BuildContext context) async {
    final target = updateInfo.targetUrl;
    final uri = Uri.tryParse(target);
    if (uri != null) {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open download link: $target'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = updateInfo.isUpdateAvailable;

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          (isNew
                                  ? AppColors.glacierAccent
                                  : AppColors.tealAccent)
                              .withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            (isNew
                                    ? AppColors.glacierAccent
                                    : AppColors.tealAccent)
                                .withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      isNew
                          ? Icons.system_update_rounded
                          : Icons.check_circle_rounded,
                      color: isNew
                          ? AppColors.glacierAccent
                          : AppColors.tealAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNew
                              ? 'New Update Available'
                              : 'Wyrm Desk is Up to Date',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isNew
                              ? 'Version v${updateInfo.latestVersion} is ready to download'
                              : 'You are running the latest version (v${updateInfo.currentVersion})',
                          style: const TextStyle(
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

              const SizedBox(height: 18),

              // Version Diff Tag (when update available)
              if (isNew) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.well,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 16,
                        color: AppColors.glacierAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v${updateInfo.currentVersion}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'v${updateInfo.latestVersion}',
                        style: const TextStyle(
                          color: AppColors.glacierAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      DuskGlassPill(
                        tintColor: AppColors.glacierAccent,
                        height: 26.0,
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: AppColors.glacierAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Markdown Release Notes
                const Text(
                  "What's New",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.well,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line, width: 1.0),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: MarkdownBody(
                      data: updateInfo.releaseNotes,
                      selectable: true,
                      softLineBreak: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                        h1: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        h2: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                        h3: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        listBullet: const TextStyle(
                          color: AppColors.glacierAccent,
                          fontSize: 12.5,
                        ),
                        code: TextStyle(
                          color: AppColors.glacierAccent,
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line, width: 1.0),
                        ),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: AppColors.glacierAccent,
                              width: 3,
                            ),
                          ),
                        ),
                        a: const TextStyle(
                          color: AppColors.glacierAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons for Update Available
                Row(
                  children: [
                    Expanded(
                      child: DuskGlassButton(
                        onPressed: () => Navigator.of(context).pop(),
                        height: 42,
                        label: const Text(
                          'Later',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DuskGlassButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _launchDownloadUrl(context);
                        },
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        icon: const Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: AppColors.glacierAccent,
                        ),
                        label: const Text(
                          'Download Update',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Action Button for Already Up To Date
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: DuskGlassButton(
                    onPressed: () => Navigator.of(context).pop(),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    label: const Text(
                      'Done',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
