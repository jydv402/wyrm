import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/settings/widgets/setting_row.dart';
import 'package:wyrm_desk/features/settings/widgets/settings_section_header.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_segmented_control.dart';

/// Section 2: Clock & Calendar panel.
class ClockCalendarSection extends ConsumerWidget {
  const ClockCalendarSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SettingsSectionHeader(
            icon: Icons.schedule_rounded,
            title: 'Clock & Calendar',
            subtitle: 'Time format and calendar week start conventions',
          ),
          const SizedBox(height: 18),
          SettingRow(
            icon: Icons.access_time_filled_rounded,
            title: 'Time Format',
            subtitle:
                'Choose between 12-hour AM/PM and 24-hour military format',
            trailing: _buildTimeFormatControl(ref, settings.is24HourFormat),
          ),
          const SizedBox(height: 12),
          SettingRow(
            icon: Icons.calendar_view_week_rounded,
            title: 'Week Starts On',
            subtitle: 'First day of the week in calendar and habit cards',
            trailing: _buildWeekStartControl(ref, settings.startWeekOnMonday),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFormatControl(WidgetRef ref, bool is24Hour) {
    return SizedBox(
      width: 220,
      child: DuskGlassSegmentedControl<bool>(
        values: const [false, true],
        selectedValue: is24Hour,
        labelBuilder: (v) => v ? '24-hour' : '12-hour',
        onValueChanged: (v) {
          ref.read(appSettingsProvider.notifier).set24HourFormat(v);
        },
        activeColor: AppColors.glacierAccent,
        activeTextColor: AppColors.glacierInk,
        height: 38,
      ),
    );
  }

  Widget _buildWeekStartControl(WidgetRef ref, bool startMonday) {
    return SizedBox(
      width: 220,
      child: DuskGlassSegmentedControl<bool>(
        values: const [false, true],
        selectedValue: startMonday,
        labelBuilder: (v) => v ? 'Monday' : 'Sunday',
        onValueChanged: (v) {
          ref.read(appSettingsProvider.notifier).setStartWeekOnMonday(v);
        },
        activeColor: AppColors.glacierAccent,
        activeTextColor: AppColors.glacierInk,
        height: 38,
      ),
    );
  }
}
