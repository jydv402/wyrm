import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Confirmation modal shown before permanently deleting a shared file or folder.
class SharingDeleteDialog extends StatelessWidget {
  /// Display name of the entry targeted for deletion.
  final String entryName;

  /// Whether the target is a directory (deleted recursively).
  final bool isDirectory;

  /// Creates a [SharingDeleteDialog].
  const SharingDeleteDialog({
    super.key,
    required this.entryName,
    required this.isDirectory,
  });

  /// Shows the confirmation dialog and returns `true` when confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String entryName,
    required bool isDirectory,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) =>
          SharingDeleteDialog(entryName: entryName, isDirectory: isDirectory),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360.0),
        child: DuskGlassPanel(
          tone: AppColors.cobalt,
          borderRadius: 24.0,
          padding: const EdgeInsetsDirectional.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              Text(
                isDirectory ? 'Delete Folder?' : 'Delete File?',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isDirectory
                    ? 'Permanently delete "$entryName" and all files inside it? '
                          'This cannot be undone.'
                    : 'Permanently delete "$entryName"? This cannot be undone.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.0,
                  height: 1.35,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8.0,
                children: [
                  DuskGlassButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    height: 36.0,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 14.0,
                    ),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                  DuskGlassButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    height: 36.0,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 16.0,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        color: AppColors.accentRed,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
