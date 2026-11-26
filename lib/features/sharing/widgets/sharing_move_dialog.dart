import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_path.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Destination folder picker modal for moving a shared file or subfolder.
class SharingMoveDialog extends StatelessWidget {
  /// Relative path of the entry being moved.
  final String sourceRelativePath;

  /// Current folder relative path where [entries] were listed.
  final String currentRelativePath;

  /// Entries visible in [currentRelativePath].
  final List<SharedFileEntry> entries;

  /// Creates a [SharingMoveDialog].
  const SharingMoveDialog({
    super.key,
    required this.sourceRelativePath,
    required this.currentRelativePath,
    required this.entries,
  });

  /// Shows the destination folder picker and returns the target relative path.
  static Future<String?> show(
    BuildContext context, {
    required String sourceRelativePath,
    required String currentRelativePath,
    required List<SharedFileEntry> entries,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => SharingMoveDialog(
        sourceRelativePath: sourceRelativePath,
        currentRelativePath: currentRelativePath,
        entries: entries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <(String label, String relativePath)>[
      if (currentRelativePath.isNotEmpty) ('Shared Root (/)', ''),
      if (currentRelativePath.contains('/'))
        (
          'Parent Folder (..)',
          SharingPath.parentRelativePath(currentRelativePath),
        ),
      for (final entry in entries)
        if (entry.isDirectory && entry.relativePath != sourceRelativePath)
          (entry.name, entry.relativePath),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360.0, maxHeight: 420.0),
        child: DuskGlassPanel(
          tone: AppColors.cobalt,
          borderRadius: 24.0,
          padding: const EdgeInsetsDirectional.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              const Text(
                'Move To Folder',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (destinations.isEmpty)
                const Padding(
                  padding: EdgeInsetsDirectional.symmetric(vertical: 12.0),
                  child: Text(
                    'No other destination folders available here.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.0,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: destinations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6.0),
                    itemBuilder: (context, index) {
                      final (label, targetPath) = destinations[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(targetPath),
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 12.0,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.well,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            spacing: 10.0,
                            children: [
                              const Icon(
                                Icons.folder_rounded,
                                size: 18.0,
                                color: AppColors.cobaltAccent,
                              ),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: DuskGlassButton(
                  onPressed: () => Navigator.of(context).pop(),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
