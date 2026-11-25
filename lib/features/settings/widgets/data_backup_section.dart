import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/data/database_service.dart';
import 'package:wyrm_desk/features/settings/widgets/setting_row.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// Section 5: Data & Backups panel.
class DataBackupSection extends ConsumerWidget {
  final String serverUrl;

  const DataBackupSection({super.key, required this.serverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          const SettingsSectionHeader(
            icon: Icons.storage_rounded,
            title: 'Data & Backups',
            subtitle: 'Backup or restore dashboard data between release and test versions',
          ),
          const SizedBox(height: 6), // Originally was 18
          SettingRow(
            icon: Icons.upload_file_rounded,
            title: 'Export backup',
            subtitle: 'Save every card, task, habit and setting to a JSON file',
            trailing: _buildExportButton(context),
          ),
          SettingRow(
            icon: Icons.download_rounded,
            title: 'Import backup',
            subtitle: 'Restore from a WYRM backup file',
            trailing: _buildImportButton(context, ref),
          ),
          const SizedBox(height: 2), // Originally was 14
          _buildTipBanner(),
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return DuskGlassButton(
      onPressed: () => _handleExport(context),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      label: const Text(
        'Export',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, WidgetRef ref) {
    return DuskGlassButton(
      onPressed: () => _handleImport(context, ref),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      label: const Text(
        'Import',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    final result = await AppDatabase.saveBackup();
    if (!context.mounted) return;
    switch (result.status) {
      case BackupFileStatus.cancelled:
        return;
      case BackupFileStatus.failed:
        _showBackupMessage(
          context,
          result.error ?? 'The backup could not be saved.',
          isError: true,
        );
      case BackupFileStatus.success:
        _showBackupMessage(context, 'Backup saved as ${result.location}.');
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final picked = await AppDatabase.openBackup();
    if (!context.mounted || picked.status == BackupFileStatus.cancelled) return;
    if (!_validateBackupFile(context, picked)) return;

    final contents = picked.contents!;
    final name = picked.location ?? AppDatabase.backupFileName;
    final confirmed = await _confirmRestore(context, name);
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(databaseServiceProvider)
        .importAndReloadJson(contents);
    if (!context.mounted) return;
    _showBackupMessage(
      context,
      success ? 'Restored $name.' : 'That backup could not be written.',
      isError: !success,
    );
  }

  bool _validateBackupFile(BuildContext context, BackupFileResult picked) {
    if (picked.status == BackupFileStatus.failed) {
      _showBackupMessage(
        context,
        picked.error ?? 'Could not open that backup.',
        isError: true,
      );
      return false;
    }
    final contents = picked.contents;
    final name = picked.location ?? AppDatabase.backupFileName;
    if (contents == null || !AppDatabase.isBackupJson(contents)) {
      _showBackupMessage(
        context,
        '$name is not a WYRM backup file.',
        isError: true,
      );
      return false;
    }
    return true;
  }

  Future<bool?> _confirmRestore(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Restore Database?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will replace your current tasks, habits, calendar, and settings with $name. Continue?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text(
              'Restore',
              style: TextStyle(color: AppColors.glacierAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.accentRed
            : AppColors.surfaceElevated,
      ),
    );
  }

  Widget _buildTipBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 10.0,
        children: [
          const Icon(
            Icons.wifi_rounded,
            size: 16,
            color: AppColors.glacierAccent,
          ),
          Expanded(
            child: Text(
              'Tip: You can also download or upload backups wirelessly from any computer or phone browser at $serverUrl',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
