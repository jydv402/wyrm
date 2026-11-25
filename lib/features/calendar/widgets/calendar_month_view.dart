import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/core/date_names.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/calendar/widgets/calendar_date_banner.dart';
import 'package:wyrm_desk/features/calendar/widgets/calendar_grid.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Compact month view: date banner, month title, and day grid.
class CalendarMonthView extends StatelessWidget {
  final CalendarState state;
  final AppSettingsConfig settings;

  const CalendarMonthView({
    super.key,
    required this.state,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = monthNames[state.viewMonth.month - 1];
    final yearString = state.viewMonth.year.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        CalendarDateBanner(state: state),
        const SizedBox(height: 4), // Originally was 12
        Text(
          '$monthName $yearString',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        Expanded(
          child: CalendarGrid(
            state: state,
            startWeekOnMonday: settings.startWeekOnMonday,
          ),
        ),
      ],
    );
  }
}
