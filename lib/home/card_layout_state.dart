import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available sizing dimensions for the clock widget.
enum ClockCardSize {
  /// Standard compact card width in the horizontal deck.
  small,

  /// Expands horizontally to occupy half of the active viewport width.
  medium,

  /// Expands to fill the entire screen below the top bar.
  large,
}

/// Identifiers for the modular cards hosted on the dashboard.
enum DashboardCardType {
  /// Clock and ambient time card.
  clock,

  /// Daily habits tracking card.
  habits,

  /// Agenda and calendar card.
  calendar,

  /// Tasks and priority management card.
  tasks,
}

/// Immutable state containing active card dimensions and full-screen overrides.
class CardLayoutState {
  /// Current horizontal size configuration for the clock card.
  final ClockCardSize clockSize;

  /// Card currently displayed in full-screen mode, or null if in default deck view.
  final DashboardCardType? fullScreenCard;

  const CardLayoutState({
    this.clockSize = ClockCardSize.small,
    this.fullScreenCard,
  });

  /// Creates a copy of the state with specified values updated.
  CardLayoutState copyWith({
    ClockCardSize? clockSize,
    DashboardCardType? Function()? fullScreenCard,
  }) {
    return CardLayoutState(
      clockSize: clockSize ?? this.clockSize,
      fullScreenCard: fullScreenCard != null ? fullScreenCard() : this.fullScreenCard,
    );
  }
}

/// Manages layout mutations, sizing adjustments, and full-screen presentations.
class CardLayoutNotifier extends Notifier<CardLayoutState> {
  @override
  CardLayoutState build() {
    return const CardLayoutState();
  }

  /// Sets the size of the clock card and adjusts full-screen mode accordingly.
  void setClockSize(ClockCardSize size) {
    if (size == ClockCardSize.large) {
      state = state.copyWith(
        clockSize: ClockCardSize.large,
        fullScreenCard: () => DashboardCardType.clock,
      );
    } else {
      state = state.copyWith(
        clockSize: size,
        fullScreenCard: () => null,
      );
    }
  }

  /// Expands or restores standard bento cards to and from full-screen presentation.
  void setCardFullScreen(DashboardCardType cardType, bool isFullScreen) {
    if (isFullScreen) {
      state = state.copyWith(
        fullScreenCard: () => cardType,
      );
    } else {
      state = state.copyWith(
        fullScreenCard: () => null,
      );
    }
  }

  /// Restores all cards back to the default bento layout.
  void restoreDefaultLayout() {
    state = const CardLayoutState();
  }
}

/// Riverpod provider exposing layout state and configuration methods.
final cardLayoutProvider =
    NotifierProvider<CardLayoutNotifier, CardLayoutState>(
  CardLayoutNotifier.new,
);
