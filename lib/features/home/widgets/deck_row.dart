import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_card.dart';
import 'package:wyrm_desk/features/clock/clock_card.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/reminder/reminder_card.dart';
import 'package:wyrm_desk/features/sharing/sharing_card.dart';
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
  final GlobalKey reminderKey;
  final GlobalKey sharingKey;
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
    required this.reminderKey,
    required this.sharingKey,
    required this.onSelectSize,
    required this.spacing,
    required this.config,
    this.clockWidget,
  });

  static double _resolveCardWidth({
    required CardSize size,
    required double smallWidth,
    required double mediumWidth,
    required double viewportWidth,
  }) {
    return switch (size) {
      CardSize.fullscreen => viewportWidth,
      CardSize.medium => mediumWidth,
      CardSize.small || CardSize.nightstand => smallWidth,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = constraints.maxWidth;
    final mediumWidth = (viewportWidth * 0.55).clamp(380.0, 900.0);

    // Primary 3 columns preserve their 1280x800 viewport fit independently of
    // Column 4 so Reminder and Sharing sit cleanly to the right via scroll.
    final bool primaryAllSmall =
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
      clockWidth = (primaryAllSmall && viewportWidth > 1100)
          ? (viewportWidth - spacing * 2) * (3.1 / 14)
          : 300.0;
    }

    // Determine whether habits and calendar remain stacked or unstack into separate columns.
    final bool centerStacked =
        config.habits == CardSize.small && config.calendar == CardSize.small;

    final double centerStackedWidth = (primaryAllSmall && viewportWidth > 1100)
        ? (viewportWidth - spacing * 2) * (6.9 / 14)
        : 540.0;

    final double habitsWidth = _resolveCardWidth(
      size: config.habits,
      smallWidth: 360.0,
      mediumWidth: mediumWidth,
      viewportWidth: viewportWidth,
    );

    final double calendarWidth = _resolveCardWidth(
      size: config.calendar,
      smallWidth: 440.0,
      mediumWidth: mediumWidth,
      viewportWidth: viewportWidth,
    );

    // Calculate tasks width based on active sizing state.
    final double tasksWidth = _resolveCardWidth(
      size: config.tasks,
      smallWidth: (primaryAllSmall && viewportWidth > 1100)
          ? (viewportWidth - spacing * 2) * (4.0 / 14)
          : 340.0,
      mediumWidth: mediumWidth,
      viewportWidth: viewportWidth,
    );

    // Column 4 geometry: when Reminder and Sharing are small, each card has
    // width = 1.75 * halfHeight (~600px on 1280x800) so full controls fit.
    final double squareCardSide = constraints.hasBoundedHeight
        ? ((constraints.maxHeight - spacing) / 2).clamp(260.0, 420.0)
        : 340.0;
    final double utilitySmallWidth = squareCardSide * 1.75;

    final bool utilityStacked =
        config.reminder == CardSize.small && config.sharing == CardSize.small;

    final double reminderWidth = _resolveCardWidth(
      size: config.reminder,
      smallWidth: utilitySmallWidth,
      mediumWidth: mediumWidth,
      viewportWidth: viewportWidth,
    );

    final double sharingWidth = _resolveCardWidth(
      size: config.sharing,
      smallWidth: utilitySmallWidth,
      mediumWidth: mediumWidth,
      viewportWidth: viewportWidth,
    );

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
          spacing: spacing,
          children: [
            // Column 1: Clock Container
            RepaintBoundary(
              child: AnimatedContainer(
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
            ),

            // Column 2: Center Section (Stacked Habits & Calendar)
            if (centerStacked)
              RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                  width: centerStackedWidth,
                  child: Column(
                    spacing: spacing,
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
                ),
              )
            else ...[
              RepaintBoundary(
                child: AnimatedContainer(
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
              ),
              RepaintBoundary(
                child: AnimatedContainer(
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
              ),
            ],

            // Column 3: Tasks Container
            RepaintBoundary(
              child: AnimatedContainer(
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
            ),

            // Column 4: Utility Section (Stacked 1.75:1 Reminder & Sharing)
            if (utilityStacked)
              RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                  width: utilitySmallWidth,
                  child: Column(
                    spacing: spacing,
                    children: [
                      Expanded(
                        child: ReminderCard(
                          key: reminderKey,
                          currentSize: config.reminder,
                          onSelectSize: (size) =>
                              onSelectSize(DashboardCardType.reminder, size),
                        ),
                      ),
                      Expanded(
                        child: SharingCard(
                          key: sharingKey,
                          currentSize: config.sharing,
                          onSelectSize: (size) =>
                              onSelectSize(DashboardCardType.sharing, size),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              RepaintBoundary(
                child: AnimatedContainer(
                  key: reminderKey,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                  width: reminderWidth,
                  child: ReminderCard(
                    currentSize: config.reminder,
                    onSelectSize: (size) =>
                        onSelectSize(DashboardCardType.reminder, size),
                  ),
                ),
              ),
              RepaintBoundary(
                child: AnimatedContainer(
                  key: sharingKey,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                  width: sharingWidth,
                  child: SharingCard(
                    currentSize: config.sharing,
                    onSelectSize: (size) =>
                        onSelectSize(DashboardCardType.sharing, size),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
