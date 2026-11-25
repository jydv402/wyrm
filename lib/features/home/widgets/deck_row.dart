import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_card.dart';
import 'package:wyrm_desk/features/clock/clock_card.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/tasks/tasks_card.dart';

/// One row of adaptive-width card columns inside a horizontally scrollable
/// canvas; column widths are computed from the viewport constraints and
/// the active [CardLayoutConfig].
class DeckRow extends StatelessWidget {
  final BoxConstraints constraints;
  final ScrollController scrollController;
  final GlobalKey clockKey;
  final GlobalKey habitsKey;
  final GlobalKey calendarKey;
  final GlobalKey tasksKey;
  final void Function(DashboardCardType type, CardSize size) onSelectSize;
  final double spacing;
  final CardLayoutConfig config;
  final Widget? clockWidget;

  const DeckRow({
    super.key,
    required this.constraints,
    required this.scrollController,
    required this.clockKey,
    required this.habitsKey,
    required this.calendarKey,
    required this.tasksKey,
    required this.onSelectSize,
    required this.spacing,
    required this.config,
    this.clockWidget,
  });

  @override
  Widget build(BuildContext context) {
    final viewportWidth = constraints.maxWidth;
    final mediumWidth = (viewportWidth * 0.55).clamp(380.0, 900.0);

    final bool allSmall =
        config.clock == CardSize.small &&
        config.habits == CardSize.small &&
        config.calendar == CardSize.small &&
        config.tasks == CardSize.small;

    // Calculate clock width based on active sizing state.
    final double clockWidth;
    if (config.clock == CardSize.fullscreen ||
        config.clock == CardSize.nightstand) {
      clockWidth = viewportWidth;
    } else if (config.clock == CardSize.medium) {
      clockWidth = mediumWidth;
    } else {
      clockWidth = (allSmall && viewportWidth > 1100)
          ? (viewportWidth - spacing * 2) * (3.1 / 14)
          : 300.0;
    }

    // Determine whether habits and calendar remain stacked or unstack into separate columns.
    final bool centerStacked =
        config.habits == CardSize.small && config.calendar == CardSize.small;

    final double centerStackedWidth = (allSmall && viewportWidth > 1100)
        ? (viewportWidth - spacing * 2) * (6.9 / 14)
        : 540.0;

    final double habitsWidth = config.habits == CardSize.fullscreen
        ? viewportWidth
        : (config.habits == CardSize.medium ? mediumWidth : 360.0);

    final double calendarWidth = config.calendar == CardSize.fullscreen
        ? viewportWidth
        : (config.calendar == CardSize.medium ? mediumWidth : 440.0);

    // Calculate tasks width based on active sizing state.
    final double tasksWidth;
    if (config.tasks == CardSize.fullscreen) {
      tasksWidth = viewportWidth;
    } else if (config.tasks == CardSize.medium) {
      tasksWidth = mediumWidth;
    } else {
      tasksWidth = (allSmall && viewportWidth > 1100)
          ? (viewportWidth - spacing * 2) * (4.0 / 14)
          : 340.0;
    }

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: viewportWidth,
          minHeight: constraints.maxHeight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column 1: Clock Container
            AnimatedContainer(
              key: clockKey,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              width: clockWidth,
              child: ClockContainer(
                currentSize: config.clock,
                onSelectSize: (size) =>
                    onSelectSize(DashboardCardType.clock, size),
                child: clockWidget,
              ),
            ),

            SizedBox(width: spacing),

            // Column 2: Center Section (Stacked Habits & Calendar)
            if (centerStacked)
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                width: centerStackedWidth,
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: HabitsCard(
                        key: habitsKey,
                        currentSize: config.habits,
                        onSelectSize: (size) =>
                            onSelectSize(DashboardCardType.habits, size),
                      ),
                    ),
                    SizedBox(height: spacing),
                    Expanded(
                      flex: 6,
                      child: CalendarCard(
                        key: calendarKey,
                        currentSize: config.calendar,
                        onSelectSize: (size) =>
                            onSelectSize(DashboardCardType.calendar, size),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              AnimatedContainer(
                key: habitsKey,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                width: habitsWidth,
                child: HabitsCard(
                  currentSize: config.habits,
                  onSelectSize: (size) =>
                      onSelectSize(DashboardCardType.habits, size),
                ),
              ),
              SizedBox(width: spacing),
              AnimatedContainer(
                key: calendarKey,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                width: calendarWidth,
                child: CalendarCard(
                  currentSize: config.calendar,
                  onSelectSize: (size) =>
                      onSelectSize(DashboardCardType.calendar, size),
                ),
              ),
            ],

            SizedBox(width: spacing),

            // Column 3: Tasks Container
            AnimatedContainer(
              key: tasksKey,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              width: tasksWidth,
              child: TasksCard(
                currentSize: config.tasks,
                onSelectSize: (size) =>
                    onSelectSize(DashboardCardType.tasks, size),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
