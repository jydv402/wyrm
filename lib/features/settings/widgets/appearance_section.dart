import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/settings/widgets/setting_row.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Section 3: Card Appearance panel.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10.0,
        children: [
          const SettingsSectionHeader(
            icon: Icons.palette_rounded,
            title: 'Card Appearance',
            subtitle: 'Typography scale for tasks, habits, and cards',
          ),
          const SizedBox(height: 8), // Originally was 18
          SettingRow(
            icon: Icons.format_size_rounded,
            title: 'Card Font Size',
            subtitle:
                'Scale checklist item and habit typography (${settings.cardFontSize.toInt()} pt)',
            trailing: _buildFontSizeControl(ref, settings),
          ),
          _buildLivePreview(settings.cardFontSize),
        ],
      ),
    );
  }

  Widget _buildFontSizeControl(WidgetRef ref, AppSettingsConfig settings) {
    return SizedBox(
      width: 240,
      child: Row(
        spacing: 6.0,
        children: [
          const Text(
            'A',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(child: _buildFontSizeSlider(ref, settings.cardFontSize)),
          const Text(
            'A',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4), // Originally was 10
          _buildFontSizeBadge(settings.cardFontSize.toInt()),
        ],
      ),
    );
  }

  Widget _buildFontSizeSlider(WidgetRef ref, double cardFontSize) {
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
        value: cardFontSize.clamp(11.0, 22.0),
        min: 11.0,
        max: 22.0,
        divisions: 11,
        onChanged: (val) {
          ref.read(appSettingsProvider.notifier).setCardFontSize(val);
        },
      ),
    );
  }

  Widget _buildFontSizeBadge(int pt) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Text(
        '$pt pt',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPreviewCheckIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.rust.fill.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.rustAccent, width: 1.5),
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 14,
        color: AppColors.rustAccent,
      ),
    );
  }

  Widget _buildLivePreview(double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 8.0,
        children: [
          _buildPreviewCheckIcon(),
          const SizedBox(width: 4), // Originally was 12
          Expanded(
            child: Text(
              'Live Preview: ${fontSize.toInt()} pt',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DuskGlassPill.priority('HIGH'),
        ],
      ),
    );
  }
}
