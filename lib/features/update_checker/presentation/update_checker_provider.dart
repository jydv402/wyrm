import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/update_checker/models/update_info.dart';
import 'package:wyrm_desk/features/update_checker/presentation/update_dialog.dart';
import 'package:wyrm_desk/features/update_checker/services/update_checker_service.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Provider exposing the update checker service.
final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  return UpdateCheckerService();
});

/// Tracks whether a manual or automated update check is currently executing.
final isCheckingUpdatesProvider = NotifierProvider<IsCheckingUpdatesNotifier, bool>(
  IsCheckingUpdatesNotifier.new,
);

class IsCheckingUpdatesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setChecking(bool value) => state = value;
}

/// Manages update checking lifecycle, caching, and dialog triggers.
class UpdateCheckerNotifier extends Notifier<AsyncValue<UpdateInfo?>> {
  @override
  AsyncValue<UpdateInfo?> build() {
    return const AsyncValue.data(null);
  }

  /// Manually checks for updates from the UI (e.g. Settings button).
  ///
  /// Displays the [UpdateDialog] for both update available and up-to-date states,
  /// or a SnackBar on connection failure.
  Future<void> checkManual(BuildContext context) async {
    final isBusy = ref.read(isCheckingUpdatesProvider);
    if (isBusy) return;

    ref.read(isCheckingUpdatesProvider.notifier).setChecking(true);
    state = const AsyncValue.loading();

    try {
      final repo = ref.read(appSettingsProvider).githubRepo;
      final service = ref.read(updateCheckerServiceProvider);
      final info = await service.check(githubRepo: repo);

      state = AsyncValue.data(info);

      if (!context.mounted) return;

      if (info != null) {
        await UpdateDialog.show(context, info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to check for updates. Please check your network connection.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.accentRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error checking for updates: $e',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      ref.read(isCheckingUpdatesProvider.notifier).setChecking(false);
    }
  }

  /// Automated background check triggered on hour rollover.
  ///
  /// Silently checks for updates only if:
  /// - Automatic checks are enabled in settings.
  /// - The tablet is not currently in Nightstand Mode.
  ///
  /// If a newer version is detected, opens the [UpdateDialog].
  Future<void> checkHourly({
    required BuildContext context,
    required bool isNightstand,
  }) async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.enableAutoUpdateChecks) return;
    if (isNightstand) return;

    final isBusy = ref.read(isCheckingUpdatesProvider);
    if (isBusy) return;

    ref.read(isCheckingUpdatesProvider.notifier).setChecking(true);
    try {
      final service = ref.read(updateCheckerServiceProvider);
      final info = await service.check(githubRepo: settings.githubRepo);

      state = AsyncValue.data(info);

      if (info != null && info.isUpdateAvailable && context.mounted) {
        // Double check nightstand mode state in case it changed during network call
        if (!isNightstand) {
          await UpdateDialog.show(context, info);
        }
      }
    } catch (_) {
      // Background hourly checks fail silently to avoid ambient interruptions
    } finally {
      ref.read(isCheckingUpdatesProvider.notifier).setChecking(false);
    }
  }
}

/// Provider managing the update check state.
final updateCheckerProvider =
    NotifierProvider<UpdateCheckerNotifier, AsyncValue<UpdateInfo?>>(
  UpdateCheckerNotifier.new,
);
