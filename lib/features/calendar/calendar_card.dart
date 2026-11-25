import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/calendar/widgets/calendar_expanded_layout.dart';
import 'package:wyrm_desk/features/calendar/widgets/calendar_month_view.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

export 'package:wyrm_desk/features/calendar/widgets/calendar_date_banner.dart';
export 'package:wyrm_desk/features/calendar/widgets/calendar_expanded_layout.dart';
export 'package:wyrm_desk/features/calendar/widgets/calendar_grid.dart';
export 'package:wyrm_desk/features/calendar/widgets/calendar_month_view.dart';
export 'package:wyrm_desk/features/calendar/widgets/milestone_tile.dart';

/// Dusk Glass Calendar card with gold/olive gradient, date banner pill,
/// and responsive day grid matching the screenshot.
class CalendarCard extends ConsumerWidget {
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;

  const CalendarCard({
    super.key,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.gold,
      icon: Icons.calendar_today_rounded,
      title: 'Calendar',
      badge: DuskCountBadge(
        label: calendarState.milestones.isEmpty
            ? null
            : '${calendarState.milestones.length}',
        color: AppColors.goldAccent,
      ),
      onAdd: () => openMilestoneTwoPaneEditor(context, ref),
      filledAdd: false,
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      child: isSmall
          ? CalendarMonthView(state: calendarState, settings: settings)
          : CalendarExpandedLayout(state: calendarState, settings: settings),
    );
  }
}
