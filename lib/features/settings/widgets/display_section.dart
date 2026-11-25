import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/features/settings/widgets/setting_row.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Section 1: Display & Brightness panel.
class DisplaySection extends ConsumerWidget {
  final bool isNightstand;

  const DisplaySection({super.key, required this.isNightstand});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayState = ref.watch(displayProvider);
    final settings = ref.watch(appSettingsProvider);
    final pct = (displayState.brightness * 100).round();

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsSectionHeader(
            icon: Icons.brightness_6_rounded,
            title: 'Display & Brightness',
            subtitle: 'Screen intensity and ambient nightstand behavior',
          ),
          const SizedBox(height: 18),
          SettingRow(
            icon: Icons.brightness_medium_rounded,
            title: 'Brightness',
            subtitle: 'Screen intensity of the tablet ambient display',
            trailing: _buildBrightnessControl(
              ref,
              displayState.brightness,
              pct,
            ),
          ),
          const SizedBox(height: 12),
          SettingRow(
            icon: Icons.format_size_rounded,
            title: 'Text Scale Clamp',
            subtitle:
                'Restricts max scale to ${(settings.maxTextScaleFactor * 100).round()}% to prevent layout overflow',
            trailing: _buildTextScaleControl(ref, settings),
          ),
          const SizedBox(height: 12),
          SettingRow(
            icon: Icons.bedtime_rounded,
            title: 'Nightstand Mode',
            subtitle: 'Pitch-black ultra-low glare glowing clock for bedtime',
            trailing: _buildNightstandSwitch(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildTextScaleControl(WidgetRef ref, AppSettingsConfig settings) {
    const options = [1.15, 1.25, 1.40];
    final currentMax = settings.maxTextScaleFactor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final opt in options) ...[
          DuskGlassPill(
            onTap: () {
              ref
                  .read(appSettingsProvider.notifier)
                  .setTextScaleRange(max: opt);
            },
            tintColor: ((currentMax - opt).abs() < 0.01)
                ? AppColors.glacierAccent
                : null,
            child: Text(
              '${(opt * 100).round()}%',
              style: TextStyle(
                color: ((currentMax - opt).abs() < 0.01)
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: ((currentMax - opt).abs() < 0.01)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildBrightnessControl(WidgetRef ref, double brightness, int pct) {
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          const Icon(
            Icons.brightness_5_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildBrightnessSlider(ref, brightness)),
          const SizedBox(width: 10),
          _buildPercentBadge(pct),
        ],
      ),
    );
  }

  Widget _buildBrightnessSlider(WidgetRef ref, double brightness) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: AppColors.glacierAccent,
        inactiveTrackColor: AppColors.lineStrong,
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(
        value: brightness.clamp(0.05, 1.0),
        min: 0.05,
        max: 1.0,
        onChanged: (val) {
          ref.read(displayProvider.notifier).setBrightness(val);
        },
      ),
    );
  }

  Widget _buildPercentBadge(int pct) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Text(
        '$pct%',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildNightstandSwitch(WidgetRef ref) {
    return Switch.adaptive(
      value: isNightstand,
      activeThumbColor: const Color(0xFFFF9500),
      activeTrackColor: const Color(0xFFFF9500).withValues(alpha: 0.35),
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.well,
      onChanged: (val) {
        ref
            .read(cardLayoutProvider.notifier)
            .setCardSize(
              DashboardCardType.clock,
              val ? CardSize.nightstand : CardSize.small,
            );
      },
    );
  }
}
