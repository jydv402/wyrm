import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/home/widgets/deck_row.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/features/update_checker/presentation/update_checker_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/top_pill_bar.dart';

export 'package:wyrm_desk/features/home/widgets/deck_row.dart';

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
                        return DeckRow(
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
