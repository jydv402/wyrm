import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Permission gate displayed when `MANAGE_EXTERNAL_STORAGE` is not yet granted.
class SharingPermissionGate extends ConsumerWidget {
  /// Whether the enclosing card is in compact `CardSize.small` mode.
  final bool isCompact;

  /// Creates a [SharingPermissionGate].
  const SharingPermissionGate({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isCompact ? 260.0 : 380.0),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: isCompact ? 6.0 : 16.0,
              vertical: 4.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: isCompact ? 6.0 : 12.0,
              children: [
                Icon(
                  Icons.folder_off_rounded,
                  size: isCompact ? 26.0 : 34.0,
                  color: AppColors.cobaltAccent,
                ),
                Text(
                  'All Files Access Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isCompact ? 13.0 : 15.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isCompact)
                  const Text(
                    'Grant storage permission on Android so the tablet can store '
                    'and share files over local Wi-Fi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    DuskGlassButton(
                      key: const ValueKey<String>(
                        'sharing_grant_access_button',
                      ),
                      onPressed: () {
                        ref.read(sharingProvider.notifier).requestPermission();
                      },
                      height: isCompact ? 34.0 : 38.0,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 14.0,
                      ),
                      icon: const Icon(
                        Icons.lock_open_rounded,
                        size: 16.0,
                        color: AppColors.cobaltAccent,
                      ),
                      label: const Text(
                        'Grant Access',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DuskGlassButton(
                      key: const ValueKey<String>(
                        'sharing_recheck_access_button',
                      ),
                      onPressed: () {
                        ref
                            .read(sharingProvider.notifier)
                            .refreshPermissionAndDirectory();
                      },
                      height: isCompact ? 34.0 : 38.0,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12.0,
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 16.0,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text(
                        'Recheck',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
