import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/calendar/calendar.dart';
import 'package:wyrm_desk/clock/clock.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/tasks/tasks.dart';

import 'card_layout_state.dart';

/// Consolidated full-screen ambient desk dashboard and application home page.
///
/// Features an anchored top navigation bar, horizontally scrollable bento cards
/// with independent Small, Medium, and Fullscreen sizing, tactile single-tap cycling,
/// smooth animated resizing, auto-scrolling focus, and a retro bottom scroll indicator.
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
  late final ScrollController _scrollController;
  Timer? _scrollAlignTimer;

  final GlobalKey _clockKey = GlobalKey();
  final GlobalKey _habitsKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _tasksKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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
    _scrollAlignTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _enableFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  GlobalKey _keyForCard(DashboardCardType type) {
    switch (type) {
      case DashboardCardType.clock:
        return _clockKey;
      case DashboardCardType.habits:
        return _habitsKey;
      case DashboardCardType.calendar:
        return _calendarKey;
      case DashboardCardType.tasks:
        return _tasksKey;
    }
  }

  /// Smoothly scrolls the horizontal deck to the start of the specified card if scrollable.
  void _scrollToCard(DashboardCardType type) {
    void performScroll() {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) return;

      final targetKey = _keyForCard(type);
      final targetContext = targetKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.0,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      performScroll();
      _scrollAlignTimer?.cancel();
      _scrollAlignTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) performScroll();
      });
    });
  }

  /// Sets the target card size and animates the viewport to bring that card into view.
  void _handleSelectSize(
    DashboardCardType type,
    CardSize size,
    GlobalKey targetKey,
  ) {
    ref.read(cardLayoutProvider.notifier).setCardSize(type, size);
    _scrollToCard(type);
  }

  @override
  Widget build(BuildContext context) {
    final layoutConfig = ref.watch(cardLayoutProvider);
    final isNightstand = layoutConfig.clock == CardSize.nightstand;

    // Listen for scroll requests originating from the web remote companion.
    ref.listen<CardScrollRequest?>(cardScrollRequestProvider, (previous, next) {
      if (next != null) {
        _scrollToCard(next.card);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          padding: isNightstand ? EdgeInsets.zero : widget.padding,
          child: Column(
            spacing: isNightstand ? 0.0 : widget.spacing,
            children: [
              // Pinned top navigation and status pill bar, smoothly hidden in nightstand mode.
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                height: isNightstand ? 0.0 : 54.0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: widget.topBar ?? const TopPillBar(),
              ),

              // Horizontally scrollable card deck with dynamic animated widths.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildScrollableDeck(
                      context: context,
                      constraints: constraints,
                      config: layoutConfig,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Constructs the horizontal scrolling row with adaptive unstacking.
  Widget _buildScrollableDeck({
    required BuildContext context,
    required BoxConstraints constraints,
    required CardLayoutConfig config,
  }) {
    final viewportWidth = constraints.maxWidth;
    final mediumWidth = (viewportWidth * 0.5).clamp(380.0, 900.0);

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
      clockWidth = (allSmall && viewportWidth > 1140)
          ? (viewportWidth - widget.spacing * 2) * (3 / 14)
          : 280.0;
    }

    // Determine whether habits and calendar remain stacked or unstack into separate columns.
    final bool centerStacked =
        config.habits == CardSize.small && config.calendar == CardSize.small;

    final double centerStackedWidth = (allSmall && viewportWidth > 1140)
        ? (viewportWidth - widget.spacing * 2) * (7 / 14)
        : 520.0;

    final double habitsWidth = config.habits == CardSize.fullscreen
        ? viewportWidth
        : (config.habits == CardSize.medium ? mediumWidth : 340.0);

    final double calendarWidth = config.calendar == CardSize.fullscreen
        ? viewportWidth
        : (config.calendar == CardSize.medium ? mediumWidth : 420.0);

    // Calculate tasks width based on active sizing state.
    final double tasksWidth;
    if (config.tasks == CardSize.fullscreen) {
      tasksWidth = viewportWidth;
    } else if (config.tasks == CardSize.medium) {
      tasksWidth = mediumWidth;
    } else {
      tasksWidth = (allSmall && viewportWidth > 1140)
          ? (viewportWidth - widget.spacing * 2) * (4 / 14)
          : 320.0;
    }

    return SingleChildScrollView(
      controller: _scrollController,
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
            // Clock container with animated width transition.
            AnimatedContainer(
              key: _clockKey,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              width: clockWidth,
              child: ClockContainer(
                currentSize: config.clock,
                onSelectSize: (size) =>
                    _handleSelectSize(DashboardCardType.clock, size, _clockKey),
                child: widget.clockWidget,
              ),
            ),

            // Center section: stacked bento column or unstacked independent columns.
            if (centerStacked)
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                width: centerStackedWidth,
                child: Column(
                  spacing: widget.spacing,
                  children: [
                    Expanded(
                      flex: 4,
                      child: HabitsCard(
                        key: _habitsKey,
                        currentSize: config.habits,
                        onSelectSize: (size) => _handleSelectSize(
                          DashboardCardType.habits,
                          size,
                          _habitsKey,
                        ),
                        child: widget.habitsWidget,
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: CalendarCard(
                        key: _calendarKey,
                        currentSize: config.calendar,
                        onSelectSize: (size) => _handleSelectSize(
                          DashboardCardType.calendar,
                          size,
                          _calendarKey,
                        ),
                        child: widget.calendarWidget,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              AnimatedContainer(
                key: _habitsKey,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                width: habitsWidth,
                child: HabitsCard(
                  currentSize: config.habits,
                  onSelectSize: (size) => _handleSelectSize(
                    DashboardCardType.habits,
                    size,
                    _habitsKey,
                  ),
                  child: widget.habitsWidget,
                ),
              ),
              AnimatedContainer(
                key: _calendarKey,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                width: calendarWidth,
                child: CalendarCard(
                  currentSize: config.calendar,
                  onSelectSize: (size) => _handleSelectSize(
                    DashboardCardType.calendar,
                    size,
                    _calendarKey,
                  ),
                  child: widget.calendarWidget,
                ),
              ),
            ],

            // Tasks container with animated width transition.
            AnimatedContainer(
              key: _tasksKey,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              width: tasksWidth,
              child: TasksCard(
                currentSize: config.tasks,
                onSelectSize: (size) =>
                    _handleSelectSize(DashboardCardType.tasks, size, _tasksKey),
                child: widget.tasksWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
