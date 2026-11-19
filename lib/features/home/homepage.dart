import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/calendar/calendar_card.dart';
import 'package:wyrm_desk/features/clock/clock_card.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/features/tasks/tasks_card.dart';
import 'package:wyrm_desk/features/home/top_pill_bar.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/update_checker/presentation/update_checker_provider.dart';

/// Consolidated full-screen ambient desk dashboard and application home page.
///
/// Features a Dusk Glass pinned top navigation bar, 3-column desk grid matching
/// the reference design, smooth animated resizing, and ambient glow backdrop.
class HomePage extends ConsumerStatefulWidget {
  /// Optional custom top bar widget.
  final Widget? topBar;

  /// Custom content injected into the clock container (used by tests).
  final Widget? clockWidget;

  /// Spacing between adjacent cards and columns.
  final double spacing;

  /// Padding around the perimeter of the master canvas.
  final EdgeInsetsGeometry padding;

  const HomePage({
    super.key,
    this.topBar,
    this.clockWidget,
    this.spacing = 6.0,
    this.padding = const EdgeInsets.all(6.0),
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
  void _handleSelectSize(DashboardCardType type, CardSize size) {
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

    // Listen for network modal requests originating from the web remote companion.
    ref.listen<bool>(networkModalOpenProvider, (previous, next) {
      if (next && !NetworkConnectionModal.isOpen) {
        NetworkConnectionModal.show(context, ref);
      } else if (!next && NetworkConnectionModal.isOpen) {
        NetworkConnectionModal.hide(ref);
      }
    });

    // Re-use live clockTimeProvider to trigger automated hourly update checks.
    ref.listen<int?>(clockTimeProvider.select((time) => time.value?.hour), (
      previous,
      next,
    ) {
      if (next != null && (previous == null || previous != next)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(updateCheckerProvider.notifier)
                .checkHourly(context: context, isNightstand: isNightstand);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Dusk Glass Backdrop Radial Glows
          if (!isNightstand)
            const Positioned.fill(
              child: IgnorePointer(child: _DuskAmbientBackdrop()),
            ),

          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeInOutCubic,
              padding: isNightstand ? EdgeInsets.zero : widget.padding,
              child: Column(
                children: [
                  // Pinned top navigation and status pill bar, smoothly hidden in nightstand mode.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    height: isNightstand ? 0.0 : 54.0,
                    margin: EdgeInsets.only(
                      bottom: isNightstand ? 0.0 : widget.spacing,
                    ),
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: widget.topBar ?? const TopPillBar(),
                  ),

                  // 3-Column Desk Grid Deck
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _DeckRow(
                          constraints: constraints,
                          scrollController: _scrollController,
                          clockKey: _clockKey,
                          habitsKey: _habitsKey,
                          calendarKey: _calendarKey,
                          tasksKey: _tasksKey,
                          onSelectSize: _handleSelectSize,
                          spacing: widget.spacing,
                          config: layoutConfig,
                          clockWidget: widget.clockWidget,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of adaptive-width card columns inside a horizontally scrollable
/// canvas; column widths are computed from the viewport constraints and
/// the active [CardLayoutConfig].
class _DeckRow extends StatelessWidget {
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

  const _DeckRow({
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

/// Atmospheric backdrop with subtle ambient destination glows matching assets/web.
class _DuskAmbientBackdrop extends StatelessWidget {
  const _DuskAmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DuskBackdropPainter());
  }
}

class _DuskBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Void base canvas
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    // Glow 1: Top-Left Slate / Peach glow
    final glow1Paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.9),
        radius: 0.9,
        colors: [
          AppColors.slate.accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow1Paint);

    // Glow 2: Bottom-Right Rust / Ember glow
    final glow2Paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, 0.95),
        radius: 0.85,
        colors: [
          AppColors.rust.accent.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow2Paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
