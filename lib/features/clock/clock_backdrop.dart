import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/clock/clock_backdrop_motion.dart';
import 'package:wyrm_desk/features/clock/clock_palette.dart';

/// Native size of the five `assets/card_bg/clock/clock_*.png` photographs.
const int _photoWidth = 3168;
const int _photoHeight = 1344;

/// Full-bleed time-of-day photograph that steps slowly across the card.
///
/// The photograph is always scaled to the card's height, so in a narrow card it
/// is several times wider than the visible area. The drift walks that spare
/// width to the far edge and back, so the whole panorama is seen over one cycle
/// instead of a single fixed crop. A wide card has no spare width and simply
/// shows the photograph still.
///
/// Movement is a fixed [ClockBackdropMotion.step] on a fixed
/// [ClockBackdropMotion.interval] - see `clockBackdropMotion` for the one place
/// to retune it. Stepping instead of tweening buys two things: the photograph
/// is only resampled when it moves a whole pixel, and a frame lost to the
/// one-second clock tick delays a step rather than jumping the image.
///
/// Nothing moves where nothing can see it. Reduced motion holds a centred crop,
/// a card scrolled out of the deck stops, and a backgrounded app stops - a
/// `Timer` keeps firing after Flutter stops producing frames, so the lifecycle
/// has to be watched explicitly.
class ClockBackdrop extends StatefulWidget {
  /// Asset path of the photograph to show.
  final String assetPath;

  /// Drift and cross-fade pacing.
  final ClockBackdropMotion motion;

  /// Legibility scrim painted over the photograph, top to bottom.
  final List<Color> scrim;

  const ClockBackdrop({
    super.key,
    required this.assetPath,
    this.motion = clockBackdropMotion,
    this.scrim = clockBackdropScrim,
  });

  @override
  State<ClockBackdrop> createState() => _ClockBackdropState();
}

class _ClockBackdropState extends State<ClockBackdrop>
    with WidgetsBindingObserver {
  /// How far the photograph is shifted left, in logical pixels, from 0 to the
  /// card's spare width.
  final ValueNotifier<double> _shift = ValueNotifier<double>(0);

  /// Spare width the photograph can cross, in logical pixels.
  double _travel = 0;

  /// +1 walking towards the right edge, -1 walking back.
  int _direction = 1;

  Timer? _ticks;
  Size _window = Size.zero;
  ScrollableState? _scrollable;
  ScrollPosition? _position;

  bool _reducedMotion = false;
  bool _animationsEnabled = true;
  bool _onScreen = true;
  bool _appActive = true;
  bool _checkQueued = false;

  /// Whether the photograph should be moving at all right now.
  bool get _shouldDrift => _tickerMayRun && _travel > 0;

  /// Whether a tick is allowed to run: on screen, in the foreground, on an
  /// active route, and not under reduced motion.
  bool get _tickerMayRun =>
      !_reducedMotion && _animationsEnabled && _onScreen && _appActive;

  /// The area the card has to overlap to be worth animating: the enclosing
  /// scroll viewport when there is one, otherwise the window.
  Rect get _viewport {
    final view = _scrollable?.context.findRenderObject();
    if (view is RenderBox && view.hasSize) {
      return view.localToGlobal(Offset.zero) & view.size;
    }
    return Offset.zero & _window;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _window = MediaQuery.sizeOf(context);
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _animationsEnabled = TickerMode.valuesOf(context).enabled;

    // The deck scrolls horizontally, so cards beside the viewport are laid out
    // and painted but never seen. Follow the scroll position to stop their
    // drift while they are away.
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (position != _position) {
      _position?.removeListener(_scheduleCheck);
      _scrollable = scrollable;
      _position = position;
      _position?.addListener(_scheduleCheck);
    }

    _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    // Applied immediately, not at the end of a frame: a paused app produces no
    // frames, so a queued check would never run while the timer kept ticking.
    _reconcile();
  }

  @override
  void dispose() {
    _ticks?.cancel();
    _position?.removeListener(_scheduleCheck);
    WidgetsBinding.instance.removeObserver(this);
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final drawnWidth = math.max(
          constraints.maxWidth,
          height * (_photoWidth / _photoHeight),
        );
        _syncTravel(drawnWidth - constraints.maxWidth);

        // Decoded to the drawn size, then quantised so a card that is animating
        // its width does not ask for a fresh decode on every frame.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final decodeWidth = math.min(
          _photoWidth,
          ((drawnWidth * dpr) / 64).ceil() * 64,
        );

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: drawnWidth,
                height: height,
                child: ValueListenableBuilder<double>(
                  valueListenable: _shift,
                  // Built once per layout, not per step: the drift moves this
                  // layer, it never rebuilds the photograph.
                  child: RepaintBoundary(
                    child: AnimatedSwitcher(
                      duration: widget.motion.crossFade,
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: Image.asset(
                        widget.assetPath,
                        key: ValueKey<String>(widget.assetPath),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: decodeWidth,
                      ),
                    ),
                  ),
                  builder: (context, shift, child) => Transform.translate(
                    offset: Offset(-shift, 0),
                    child: child,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.scrim,
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Records the spare width after layout.
  ///
  /// Called from the build phase, so the placement it triggers is deferred to
  /// the end of the frame and never marks anything dirty mid-build.
  void _syncTravel(double travel) {
    if ((travel - _travel).abs() < 0.5) return;
    _travel = travel;
    _scheduleCheck();
  }

  /// Queues one visibility check for the end of the frame.
  ///
  /// Scroll positions can notify from inside a layout pass, and the check moves
  /// the photograph, so it must never run while the tree is locked.
  void _scheduleCheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _refresh();
    });
  }

  /// Re-checks visibility and applies the placement that depends on the card's
  /// size, then starts or stops the drift to match.
  void _refresh() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      _onScreen = (box.localToGlobal(Offset.zero) & box.size).overlaps(
        _viewport,
      );
    }
    _reconcile();
  }

  void _reconcile() {
    if (!mounted) return;
    if (_reducedMotion) {
      _shift.value = _travel / 2; // Hold the middle of the panorama.
    } else if (_shift.value > _travel) {
      _shift.value = _travel;
    }

    if (_shouldDrift) {
      _ticks ??= Timer.periodic(widget.motion.interval, (_) => _step());
    } else {
      _ticks?.cancel();
      _ticks = null;
    }
  }

  /// Advances the photograph one step, turning around at either edge.
  void _step() {
    if (_travel <= 0) return;
    var next = _shift.value + _direction * widget.motion.step;
    if (next >= _travel) {
      next = _travel;
      _direction = -1;
    } else if (next <= 0) {
      next = 0;
      _direction = 1;
    }
    _shift.value = next;
  }
}
