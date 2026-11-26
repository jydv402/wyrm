import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/sharing/sharing_mime.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Actions available on a file or folder row in [SharingBrowserBody].
enum SharingEntryAction { open, shareQr, rename, move, delete }

/// Single file or directory row inside the tablet sharing browser.
class SharingFileTile extends StatelessWidget {
  /// Directory or file entry represented by this row.
  final SharedFileEntry entry;

  /// Invoked when the row itself is tapped.
  final VoidCallback onTap;

  /// Invoked when an item from the trailing action menu is selected.
  final ValueChanged<SharingEntryAction> onAction;

  /// Creates a [SharingFileTile].
  const SharingFileTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDirectory = entry.isDirectory;
    final iconData = _resolveIcon(entry);
    final subtitle = isDirectory
        ? 'Folder'
        : SharingMime.formatByteSize(entry.sizeBytes);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          padding: const EdgeInsetsDirectional.only(
            start: 12.0,
            end: 4.0,
            top: 8.0,
            bottom: 8.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.well,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            spacing: 10.0,
            children: [
              Icon(
                iconData,
                size: 20.0,
                color: isDirectory
                    ? AppColors.cobaltAccent
                    : AppColors.textSecondary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2.0,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<SharingEntryAction>(
                onSelected: onAction,
                color: AppColors.surfaceElevated,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18.0,
                  color: AppColors.textSecondary,
                ),
                itemBuilder: (context) => <PopupMenuEntry<SharingEntryAction>>[
                  PopupMenuItem<SharingEntryAction>(
                    value: SharingEntryAction.open,
                    child: Text(
                      isDirectory ? 'Open folder' : 'Open',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  if (!isDirectory)
                    const PopupMenuItem<SharingEntryAction>(
                      value: SharingEntryAction.shareQr,
                      child: Text(
                        'Share QR link',
                        style: TextStyle(color: AppColors.cobaltAccent),
                      ),
                    ),
                  const PopupMenuItem<SharingEntryAction>(
                    value: SharingEntryAction.rename,
                    child: Text(
                      'Rename',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const PopupMenuItem<SharingEntryAction>(
                    value: SharingEntryAction.move,
                    child: Text(
                      'Move',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const PopupMenuItem<SharingEntryAction>(
                    value: SharingEntryAction.delete,
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.accentRed),
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

  static IconData _resolveIcon(SharedFileEntry entry) {
    if (entry.isDirectory) return Icons.folder_rounded;
    final mime = entry.mimeType;
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.movie_rounded;
    if (mime.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (mime.startsWith('text/') || mime.contains('json')) {
      return Icons.description_rounded;
    }
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('7z')) {
      return Icons.archive_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
