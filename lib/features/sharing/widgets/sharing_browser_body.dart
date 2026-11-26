import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_breadcrumb_bar.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_delete_dialog.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_file_tile.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_move_dialog.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_permission_gate.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_qr_dialog.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_text_prompt_dialog.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Full tablet file manager body for [SharingCard] in [CardSize.medium] and
/// [CardSize.fullscreen].
class SharingBrowserBody extends ConsumerWidget {
  /// Creates a [SharingBrowserBody].
  const SharingBrowserBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(
      sharingProvider.select((s) => s.hasPermission),
    );
    if (!hasPermission) {
      return const SharingPermissionGate();
    }

    final browserState = ref.watch(
      sharingProvider.select(
        (s) => (
          currentRelativePath: s.currentRelativePath,
          entries: s.entries,
          isLoading: s.isLoading,
          errorMessage: s.errorMessage,
          password: s.passwordDisplay,
        ),
      ),
    );

    final ip = ref.watch(localIpProvider).value ?? '127.0.0.1';
    final port =
        ref.watch(webServerProvider.select((s) => s.port)) ??
        ShelfWebServer.defaultPort;
    final baseUrl = 'http://$ip:$port';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        _BrowserActionStrip(password: browserState.password, baseUrl: baseUrl),
        SharingBreadcrumbBar(
          currentRelativePath: browserState.currentRelativePath,
          onNavigate: (path) {
            ref.read(sharingProvider.notifier).navigateTo(path);
          },
          onNavigateUp: () {
            ref.read(sharingProvider.notifier).navigateUp();
          },
        ),
        if (browserState.errorMessage != null)
          _BrowserErrorBanner(message: browserState.errorMessage!),
        Expanded(
          child: browserState.entries.isEmpty
              ? _EmptyFolderNotice(isLoading: browserState.isLoading)
              : ListView.separated(
                  itemCount: browserState.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6.0),
                  itemBuilder: (context, index) {
                    final entry = browserState.entries[index];
                    return SharingFileTile(
                      key: ValueKey<String>(entry.relativePath),
                      entry: entry,
                      onTap: () {
                        ref.read(sharingProvider.notifier).openEntry(entry);
                      },
                      onAction: (action) => _handleEntryAction(
                        context,
                        ref,
                        action,
                        entry,
                        browserState.currentRelativePath,
                        browserState.entries,
                        baseUrl,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _handleEntryAction(
    BuildContext context,
    WidgetRef ref,
    SharingEntryAction action,
    SharedFileEntry entry,
    String currentRelativePath,
    List<SharedFileEntry> entries,
    String baseUrl,
  ) async {
    final notifier = ref.read(sharingProvider.notifier);
    switch (action) {
      case SharingEntryAction.open:
        await notifier.openEntry(entry);
      case SharingEntryAction.shareQr:
        final token = notifier.issueShareToken();
        final encodedPath = Uri.encodeComponent(entry.relativePath);
        final downloadUrl =
            '$baseUrl/api/sharing/download?path=$encodedPath&token=$token';
        if (!context.mounted) return;
        await SharingQrDialog.show(
          context,
          title: entry.name,
          subtitle: 'Scan on another device to download this file directly.',
          url: downloadUrl,
        );
      case SharingEntryAction.rename:
        final newName = await SharingTextPromptDialog.show(
          context,
          title: 'Rename Entry',
          hintText: 'New name',
          confirmLabel: 'Rename',
          initialValue: entry.name,
        );
        if (newName == null || newName == entry.name) return;
        await notifier.renameEntry(entry.relativePath, newName);
      case SharingEntryAction.move:
        final targetDir = await SharingMoveDialog.show(
          context,
          sourceRelativePath: entry.relativePath,
          currentRelativePath: currentRelativePath,
          entries: entries,
        );
        if (targetDir == null) return;
        await notifier.moveEntry(entry.relativePath, targetDir);
      case SharingEntryAction.delete:
        final confirmed = await SharingDeleteDialog.show(
          context,
          entryName: entry.name,
          isDirectory: entry.isDirectory,
        );
        if (!confirmed) return;
        await notifier.deleteEntry(entry.relativePath);
    }
  }
}

class _BrowserActionStrip extends ConsumerWidget {
  final String password;
  final String baseUrl;

  const _BrowserActionStrip({required this.password, required this.baseUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: password));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sharing password copied'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 9.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: AppColors.cobaltAccent.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 5.0,
              children: [
                const Icon(
                  Icons.key_rounded,
                  size: 13.0,
                  color: AppColors.cobaltAccent,
                ),
                Text(
                  password,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        DuskGlassButton(
          onPressed: () {
            ref.read(sharingProvider.notifier).importFromDevicePicker();
          },
          height: 32.0,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10.0),
          icon: const Icon(
            Icons.upload_file_rounded,
            size: 15.0,
            color: AppColors.cobaltAccent,
          ),
          label: const Text(
            'Import',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 12.0),
          ),
        ),
        DuskGlassButton(
          onPressed: () async {
            final name = await SharingTextPromptDialog.show(
              context,
              title: 'New Folder',
              hintText: 'Folder name',
              confirmLabel: 'Create',
            );
            if (name == null) return;
            await ref.read(sharingProvider.notifier).createFolder(name);
          },
          height: 32.0,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10.0),
          icon: const Icon(
            Icons.create_new_folder_rounded,
            size: 15.0,
            color: AppColors.cobaltAccent,
          ),
          label: const Text(
            'Folder',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 12.0),
          ),
        ),
        DuskGlassButton(
          onPressed: () {
            SharingQrDialog.show(
              context,
              title: 'Web Remote Sharing',
              subtitle: 'Scan to upload or download files over local Wi-Fi.',
              url: baseUrl,
              passwordHint: password,
            );
          },
          height: 32.0,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10.0),
          icon: const Icon(
            Icons.qr_code_2_rounded,
            size: 15.0,
            color: AppColors.cobaltAccent,
          ),
        ),
        DuskGlassButton(
          onPressed: () {
            ref.read(sharingProvider.notifier).refreshPermissionAndDirectory();
          },
          height: 32.0,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10.0),
          icon: const Icon(
            Icons.refresh_rounded,
            size: 15.0,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BrowserErrorBanner extends StatelessWidget {
  final String message;

  const _BrowserErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10.0,
        vertical: 7.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.40)),
      ),
      child: Text(
        message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.accentRed, fontSize: 12.0),
      ),
    );
  }
}

class _EmptyFolderNotice extends StatelessWidget {
  final bool isLoading;

  const _EmptyFolderNotice({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 24.0,
          height: 24.0,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.cobaltAccent,
          ),
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6.0,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 30.0,
            color: AppColors.textMuted,
          ),
          Text(
            'This folder is empty',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.0),
          ),
        ],
      ),
    );
  }
}
