import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/calendar/calendar.dart';
import 'package:wyrm_desk/clock/clock.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/tasks/tasks.dart';
import 'card_layout_state.dart';
import 'card_size_dialog.dart';

/// Consolidated full-screen ambient desk dashboard and application home page.
///
/// Automatically manages full-screen immersive sticky system UI mode,
/// handles app lifecycle transitions, and presents the responsive bento desk layout.
class HomePage extends ConsumerStatefulWidget {
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

  const HomePage({
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
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableFullScreen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableFullScreen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _enableFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(cardLayoutProvider);
    final layoutNotifier = ref.read(cardLayoutProvider.notifier);

    return Scaffold(
      body: Padding(
        padding: widget.padding,
        child: Column(
          spacing: widget.spacing,
          children: [
            // Pinned top navigation and status pill bar.
            widget.topBar ?? const TopPillBar(),

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
                        ? _buildFullScreenView(
                            key: ValueKey(activeFullScreen),
                            context: context,
                            cardType: activeFullScreen,
                            layoutState: layoutState,
                            notifier: layoutNotifier,
                          )
                        : _buildHorizontalDeck(
                            key: const ValueKey('horizontal_deck_scroll_view'),
                            context: context,
                            constraints: constraints,
                            layoutState: layoutState,
                            notifier: layoutNotifier,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the horizontally scrolling bento deck with animated column sizing.
  Widget _buildHorizontalDeck({
    required Key key,
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
          ? (viewportWidth - widget.spacing * 2) * (3 / 14)
          : 280.0;
    }

    // Resolve column widths for center and right sections.
    final double centerWidth;
    final double rightWidth;
    if (layoutState.clockSize == ClockCardSize.small && viewportWidth > 1140) {
      centerWidth = (viewportWidth - widget.spacing * 2) * (7 / 14);
      rightWidth = (viewportWidth - widget.spacing * 2) * (4 / 14);
    } else {
      centerWidth = 520.0;
      rightWidth = 320.0;
    }

    return SingleChildScrollView(
      key: key,
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
          spacing: widget.spacing,
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
                child: widget.clockWidget,
              ),
            ),

            // Center column containing habits and calendar cards.
            SizedBox(
              width: centerWidth,
              child: Column(
                spacing: widget.spacing,
                children: [
                  Expanded(
                    flex: 4,
                    child: HabitsCard(
                      onEdit: () => _openSizeDialog(
                        context: context,
                        cardType: DashboardCardType.habits,
                        layoutState: layoutState,
                        notifier: notifier,
                      ),
                      child: widget.habitsWidget,
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: CalendarCard(
                      onEdit: () => _openSizeDialog(
                        context: context,
                        cardType: DashboardCardType.calendar,
                        layoutState: layoutState,
                        notifier: notifier,
                      ),
                      child: widget.calendarWidget,
                    ),
                  ),
                ],
              ),
            ),

            // Right column containing tasks container.
            SizedBox(
              width: rightWidth,
              child: TasksCard(
                child: widget.tasksWidget,
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
    required Key key,
    required BuildContext context,
    required DashboardCardType cardType,
    required CardLayoutState layoutState,
    required CardLayoutNotifier notifier,
  }) {
    final VoidCallback onExit = notifier.restoreDefaultLayout;

    switch (cardType) {
      case DashboardCardType.clock:
        return ClockContainer(
          key: key,
          isFullScreen: true,
          onEdit: onExit,
          child: widget.clockWidget,
        );
      case DashboardCardType.habits:
        return HabitsCard(
          key: key,
          isFullScreen: true,
          onEdit: onExit,
          child: widget.habitsWidget,
        );
      case DashboardCardType.calendar:
        return CalendarCard(
          key: key,
          isFullScreen: true,
          onEdit: onExit,
          child: widget.calendarWidget,
        );
      case DashboardCardType.tasks:
        return TasksCard(
          key: key,
          isFullScreen: true,
          onEdit: onExit,
          child: widget.tasksWidget,
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
