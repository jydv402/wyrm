import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/display/display_state.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/server/network_info.dart';
import 'package:wyrm_desk/server/network_modal.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Dusk Glass modal dialog displaying application configuration options.
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  /// Displays the settings modal dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final displayState = ref.watch(displayProvider);
    final layoutConfig = ref.watch(cardLayoutProvider);
    final isNightstand = layoutConfig.clock == CardSize.nightstand;

    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final serverUrl = 'http://$ipAddress:8080';

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.slateAccent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.slateAccent.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: AppColors.slateAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DuskGlassButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      size: 32,
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Configure ambient display, clock preferences, and web remote.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Display Brightness Slider Row
                _buildSettingContainer(
                  icon: Icons.brightness_6_rounded,
                  title: 'Brightness',
                  subtitle: '${(displayState.brightness * 100).toInt()}% display intensity',
                  trailing: SizedBox(
                    width: 140,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        activeTrackColor: AppColors.accentOrange,
                        inactiveTrackColor: AppColors.lineStrong,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: displayState.brightness.clamp(0.05, 1.0),
                        min: 0.05,
                        max: 1.0,
                        onChanged: (val) {
                          ref.read(displayProvider.notifier).setBrightness(val);
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 24-Hour Time Format Switch
                _buildSettingContainer(
                  icon: Icons.schedule_rounded,
                  title: '24-Hour Time',
                  subtitle: 'Format clock as 24h instead of 12h',
                  trailing: Switch.adaptive(
                    value: settings.is24HourFormat,
                    activeThumbColor: AppColors.accentOrange,
                    activeTrackColor: AppColors.accentOrange.withValues(alpha: 0.35),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.well,
                    onChanged: (val) => notifier.set24HourFormat(val),
                  ),
                ),

                const SizedBox(height: 10),

                // Start Week on Monday Switch
                _buildSettingContainer(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'Start Week on Monday',
                  subtitle: 'Calendar starts on Monday instead of Sunday',
                  trailing: Switch.adaptive(
                    value: settings.startWeekOnMonday,
                    activeThumbColor: AppColors.accentOrange,
                    activeTrackColor: AppColors.accentOrange.withValues(alpha: 0.35),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.well,
                    onChanged: (val) => notifier.setStartWeekOnMonday(val),
                  ),
                ),

                const SizedBox(height: 10),

                // Classic Modal Sheet Toggle
                _buildSettingContainer(
                  icon: Icons.view_sidebar_rounded,
                  title: 'Classic Modal Sheet',
                  subtitle: 'Use bottom sheet instead of 2-pane keyboard editor',
                  trailing: Switch.adaptive(
                    value: settings.useClassicModalSheet,
                    activeThumbColor: AppColors.tealAccent,
                    activeTrackColor: AppColors.tealAccent.withValues(alpha: 0.35),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.well,
                    onChanged: (val) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setUseClassicModalSheet(val);
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Nightstand Mode Toggle
                _buildSettingContainer(
                  icon: Icons.bedtime_rounded,
                  title: 'Nightstand Mode',
                  subtitle: 'Pitch-black ultra-low glare glowing clock',
                  trailing: Switch.adaptive(
                    value: isNightstand,
                    activeThumbColor: const Color(0xFFFF9500),
                    activeTrackColor: const Color(0xFFFF9500).withValues(alpha: 0.35),
                    inactiveThumbColor: AppColors.textSecondary,
                    inactiveTrackColor: AppColors.well,
                    onChanged: (val) {
                      ref.read(cardLayoutProvider.notifier).setCardSize(
                            DashboardCardType.clock,
                            val ? CardSize.nightstand : CardSize.small,
                          );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Web Remote Banner Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.well,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_rounded, size: 18, color: AppColors.tealAccent),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Web Remote Companion',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DuskGlassButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              NetworkConnectionModal.show(context);
                            },
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            label: const Text(
                              'Show QR',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        serverUrl,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingContainer({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.slateAccent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}
