import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/calendar/dusk_date_picker_dialog.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Top Date Banner Bar matching reference screenshot:
/// Left: [Sat, Sep 19 • Day 262/365 · Year 72%]
/// Right: [Today] [Travel] [<] [>]
class CalendarDateBanner extends ConsumerWidget {
  final CalendarState state;

  const CalendarDateBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = CalendarState.todayMidnight;
    final isSelectedToday =
        state.selectedDate.year == today.year &&
        state.selectedDate.month == today.month &&
        state.selectedDate.day == today.day;
    final isMarkerOnToday =
        isSelectedToday &&
        state.viewMonth.year == today.year &&
        state.viewMonth.month == today.month;

    final dateStr = DateFormat('EEE, MMM d').format(state.selectedDate);
    final telemetry = isSelectedToday
        ? 'Day ${state.dayOfYear}/${state.daysInYear} · Year ${(state.yearProgress * 100).toStringAsFixed(0)}%'
        : state.relativeDistanceText;

    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildBannerContent(
          context,
          ref,
          constraints.maxWidth < 360,
          dateStr,
          telemetry,
          isMarkerOnToday,
        );
      },
    );
  }

  Widget _buildBannerContent(
    BuildContext context,
    WidgetRef ref,
    bool isCompact,
    String dateStr,
    String telemetry,
    bool isMarkerOnToday,
  ) {
    final btnHeight = isCompact ? 32.0 : 38.0;
    final btnPadding = EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 12.0);
    final chevronSize = isCompact ? 32.0 : 38.0;
    final gap = 8.0;

    return Row(
      spacing: gap,
      children: [
        Expanded(
          child: _buildTelemetryPill(btnHeight, isCompact, dateStr, telemetry),
        ),
        if (!isMarkerOnToday) ...[
          _buildTodayButton(ref, btnHeight, btnPadding),
        ],

        _buildTravelButton(context, ref, btnHeight, btnPadding),

        _buildChevronButton(
          ref,
          isPrev: true,
          size: chevronSize,
          isCompact: isCompact,
        ),

        _buildChevronButton(
          ref,
          isPrev: false,
          size: chevronSize,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildTelemetryPill(
    double btnHeight,
    bool isCompact,
    String dateStr,
    String telemetry,
  ) {
    return Container(
      height: btnHeight,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 14),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6.0,
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.goldAccent,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              telemetry,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayButton(WidgetRef ref, double height, EdgeInsets padding) {
    return DuskGlassButton(
      key: const ValueKey('calendar_today_btn'),
      onPressed: () => ref.read(calendarProvider.notifier).resetToToday(),
      height: height,
      padding: padding,
      label: const Text(
        'Today',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTravelButton(
    BuildContext context,
    WidgetRef ref,
    double height,
    EdgeInsets padding,
  ) {
    return DuskGlassButton(
      key: const ValueKey('calendar_travel_btn'),
      onPressed: () => openTravelDatePicker(context, ref, state.selectedDate),
      height: height,
      padding: padding,
      label: const Text(
        'Travel',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChevronButton(
    WidgetRef ref, {
    required bool isPrev,
    required double size,
    required bool isCompact,
  }) {
    return DuskGlassButton.icon(
      key: ValueKey(
        isPrev ? 'calendar_prev_month_btn' : 'calendar_next_month_btn',
      ),
      onPressed: isPrev
          ? () => ref.read(calendarProvider.notifier).prevMonth()
          : () => ref.read(calendarProvider.notifier).nextMonth(),
      icon: Icon(
        isPrev ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        size: isCompact ? 16 : 18,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Opens Dusk Glass date picker configured with TRAVEL confirm text and month/year selectors.
Future<void> openTravelDatePicker(
  BuildContext context,
  WidgetRef ref,
  DateTime initialDate,
) async {
  final picked = await showDialog<DateTime>(
    context: context,
    builder: (context) => DuskDatePickerDialog(
      initialDate: initialDate,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      confirmText: 'Travel',
      cancelText: 'Cancel',
    ),
  );
  if (picked != null) {
    ref.read(calendarProvider.notifier).selectDate(picked);
  }
}
