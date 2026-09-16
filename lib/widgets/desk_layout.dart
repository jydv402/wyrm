import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/theme.dart';

import 'calendar_card.dart';
import 'card_layout_state.dart';
import 'card_size_dialog.dart';
import 'clock_card.dart';
import 'habits_card.dart';
import 'tasks_card.dart';
import 'top_pill_bar.dart';

/// Full-screen ambient desk layout providing horizontal scrolling and dynamic container resizing.
class DeskLayout extends ConsumerWidget {
  /// Optional custom top bar widget.
  final Widget? topBar;

  /// Custom content injected into the clock container.
  final Widget? clockWidget;

  /// Custom content injected into the habits container.
  final Widget? habitsWidget;

  /// Custom content injected into the calendar container.
  final Widget? calendarWidget;

  /// Custom content injected into the tasks container.
  final Widget? tasksWidget;

  /// Spacing between adjacent bento cards and columns.
  final double spacing;

  /// Padding around the perimeter of the master canvas.
  final EdgeInsetsGeometry padding;

  const DeskLayout({
    super.key,
    this.topBar,
    this.clockWidget,
    this.habitsWidget,
    this.calendarWidget,
    this.tasksWidget,
    this.spacing = 10.0,
    this.padding = const EdgeInsets.all(12.0),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutState = ref.watch(cardLayoutProvider);
    final layoutNotifier = ref.read(cardLayoutProvider.notifier);

    return Container(
      color: AppColors.background,
      padding: padding,
      child: Column(
        spacing: spacing,
        children: [
          // Pinned top navigation and status pill bar.
          topBar ?? const TopPillBar(),

          // Body region hosting either the horizontal card deck or an expanded full-screen card.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final activeFullScreen = layoutState.fullScreenCard;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: activeFullScreen != null
                      ? KeyedSubtree(
                          key: ValueKey(activeFullScreen),
                          child: _buildFullScreenView(
                            context: context,
                            cardType: activeFullScreen,
                            layoutState: layoutState,
                            notifier: layoutNotifier,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('horizontal_deck_scroll_view'),
                          child: _buildHorizontalDeck(
                            context: context,
                            constraints: constraints,
                            layoutState: layoutState,
                            notifier: layoutNotifier,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the horizontally scrolling bento deck with animated column sizing.
  Widget _buildHorizontalDeck({
    required BuildContext context,
    required BoxConstraints constraints,
    required CardLayoutState layoutState,
    required CardLayoutNotifier notifier,
  }) {
    final viewportWidth = constraints.maxWidth;

    // Resolve dynamic width for the clock card based on active sizing state.
    final double clockWidth;
    if (layoutState.clockSize == ClockCardSize.medium) {
      clockWidth = (viewportWidth * 0.5).clamp(420.0, 900.0);
    } else {
      clockWidth = (viewportWidth > 1140)
          ? (viewportWidth - spacing * 2) * (3 / 14)
          : 280.0;
    }

    // Resolve column widths for center and right sections.
    final double centerWidth;
    final double rightWidth;
    if (layoutState.clockSize == ClockCardSize.small && viewportWidth > 1140) {
      centerWidth = (viewportWidth - spacing * 2) * (7 / 14);
      rightWidth = (viewportWidth - spacing * 2) * (4 / 14);
    } else {
      centerWidth = 520.0;
      rightWidth = 320.0;
    }

    return SingleChildScrollView(
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
            // Left column containing the dynamically resizable clock container.
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              width: clockWidth,
              child: ClockContainer(
                onEdit: () => _openSizeDialog(
                  context: context,
                  cardType: DashboardCardType.clock,
                  layoutState: layoutState,
                  notifier: notifier,
                ),
                child: clockWidget,
              ),
            ),
            SizedBox(width: spacing),

            // Center column containing habits and calendar cards.
            SizedBox(
              width: centerWidth,
              child: CenterBentoColumn(
                spacing: spacing,
                topChild: habitsWidget,
                bottomChild: calendarWidget,
                onEditHabits: () => _openSizeDialog(
                  context: context,
                  cardType: DashboardCardType.habits,
                  layoutState: layoutState,
                  notifier: notifier,
                ),
                onEditCalendar: () => _openSizeDialog(
                  context: context,
                  cardType: DashboardCardType.calendar,
                  layoutState: layoutState,
                  notifier: notifier,
                ),
              ),
            ),
            SizedBox(width: spacing),

            // Right column containing quick action buttons and tasks container.
            SizedBox(
              width: rightWidth,
              child: TasksCard(
                child: tasksWidget,
                onEdit: () => _openSizeDialog(
                  context: context,
                  cardType: DashboardCardType.tasks,
                  layoutState: layoutState,
                  notifier: notifier,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a full-screen presentation view for any expanded card.
  Widget _buildFullScreenView({
    required BuildContext context,
    required DashboardCardType cardType,
    required CardLayoutState layoutState,
    required CardLayoutNotifier notifier,
  }) {
    final VoidCallback onExit = notifier.restoreDefaultLayout;

    switch (cardType) {
      case DashboardCardType.clock:
        return ClockContainer(
          isFullScreen: true,
          onEdit: onExit,
          child: clockWidget,
        );
      case DashboardCardType.habits:
        return HabitsCard(
          isFullScreen: true,
          onEdit: onExit,
          child: habitsWidget,
        );
      case DashboardCardType.calendar:
        return CalendarCard(
          isFullScreen: true,
          onEdit: onExit,
          child: calendarWidget,
        );
      case DashboardCardType.tasks:
        return TasksCard(
          isFullScreen: true,
          onEdit: onExit,
          child: tasksWidget,
        );
    }
  }

  /// Launches the bento container sizing dialog.
  void _openSizeDialog({
    required BuildContext context,
    required DashboardCardType cardType,
    required CardLayoutState layoutState,
    required CardLayoutNotifier notifier,
  }) {
    CardSizeDialog.show(
      context: context,
      cardType: cardType,
      currentClockSize: layoutState.clockSize,
      isFullScreen: layoutState.fullScreenCard == cardType,
      onClockSizeSelected: (size) => notifier.setClockSize(size),
      onFullScreenToggled: (isFull) =>
          notifier.setCardFullScreen(cardType, isFull),
    );
  }
}

/// Center column of the dashboard containing the top Habits card and bottom Calendar card.
class CenterBentoColumn extends StatelessWidget {
  final Widget? topChild;
  final Widget? bottomChild;
  final VoidCallback? onEditHabits;
  final VoidCallback? onEditCalendar;
  final double spacing;
  final int topFlex;
  final int bottomFlex;

  const CenterBentoColumn({
    super.key,
    this.topChild,
    this.bottomChild,
    this.onEditHabits,
    this.onEditCalendar,
    this.spacing = 10.0,
    this.topFlex = 4,
    this.bottomFlex = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: topFlex,
          child: HabitsCard(onEdit: onEditHabits, child: topChild),
        ),
        SizedBox(height: spacing),
        Expanded(
          flex: bottomFlex,
          child: CalendarCard(onEdit: onEditCalendar, child: bottomChild),
        ),
      ],
    );
  }
}
