import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/widgets/card_edit_button.dart';

/// Available sizing dimensions for bento cards across the horizontal layout.
enum CardSize {
  /// Standard compact card width in the horizontal deck.
  small,

  /// Expands horizontally to occupy half of the active viewport width.
  medium,

  /// Expands horizontally to occupy the entire viewport width.
  fullscreen,

  /// Expands to full screen with pitch black canvas and amber nightstand theme.
  nightstand;

  /// Resolves the human-readable display label.
  String get label {
    switch (this) {
      case CardSize.small:
        return 'Small';
      case CardSize.medium:
        return 'Medium';
      case CardSize.fullscreen:
        return 'Fullscreen';
      case CardSize.nightstand:
        return 'Nightstand';
    }
  }

  /// Resolves the popup-menu icon for the shared card-size control.
  IconData get menuIcon {
    switch (this) {
      case CardSize.small:
        return Icons.crop_square_rounded;
      case CardSize.medium:
        return Icons.view_column_rounded;
      case CardSize.fullscreen:
        return Icons.fullscreen_rounded;
      case CardSize.nightstand:
        return Icons.bedtime_rounded;
    }
  }
}

/// Popup-menu entries for the shared card-size [CardEditButton], ordered
/// small → medium → fullscreen, with the clock-only Nightstand tier last.
List<EditMenuOption<CardSize>> cardSizeMenuOptions({
  bool includeNightstand = false,
}) {
  const tiers = CardSize.values;
  return [
    for (final size in includeNightstand ? tiers : tiers.take(3))
      EditMenuOption(value: size, label: size.label, icon: size.menuIcon),
  ];
}

/// Identifiers for the primary modular cards hosted on the dashboard.
enum DashboardCardType {
  /// Clock and ambient time card.
  clock,

  /// Daily habits tracking card.
  habits,

  /// Agenda and calendar card.
  calendar,

  /// Tasks and priority management card.
  tasks;

  /// Safely resolves a card type from a dynamic string token.
  static DashboardCardType? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase().trim();
    for (final entry in DashboardCardType.values) {
      if (entry.name.toLowerCase() == normalized) {
        return entry;
      }
    }
    return null;
  }
}

/// Immutable configuration model mapping each dashboard card to its active size.
class CardLayoutConfig {
  final CardSize clock;
  final CardSize habits;
  final CardSize calendar;
  final CardSize tasks;

  const CardLayoutConfig({
    this.clock = CardSize.small,
    this.habits = CardSize.small,
    this.calendar = CardSize.small,
    this.tasks = CardSize.small,
  });

  /// Resolves the active size for the specified card type.
  CardSize sizeFor(DashboardCardType type) {
    switch (type) {
      case DashboardCardType.clock:
        return clock;
      case DashboardCardType.habits:
        return habits;
      case DashboardCardType.calendar:
        return calendar;
      case DashboardCardType.tasks:
        return tasks;
    }
  }

  /// Returns a new configuration with the designated card size updated.
  CardLayoutConfig withSize(DashboardCardType type, CardSize size) {
    switch (type) {
      case DashboardCardType.clock:
        return copyWith(clock: size);
      case DashboardCardType.habits:
        return copyWith(habits: size);
      case DashboardCardType.calendar:
        return copyWith(calendar: size);
      case DashboardCardType.tasks:
        return copyWith(tasks: size);
    }
  }

  /// Creates a copy of the configuration with specified overrides.
  CardLayoutConfig copyWith({
    CardSize? clock,
    CardSize? habits,
    CardSize? calendar,
    CardSize? tasks,
  }) {
    return CardLayoutConfig(
      clock: clock ?? this.clock,
      habits: habits ?? this.habits,
      calendar: calendar ?? this.calendar,
      tasks: tasks ?? this.tasks,
    );
  }

  /// Serializes the layout configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'clock': clock.name,
      'habits': habits.name,
      'calendar': calendar.name,
      'tasks': tasks.name,
    };
  }

  /// Deserializes the layout configuration from a JSON map.
  factory CardLayoutConfig.fromJson(Map<String, dynamic> json) {
    return CardLayoutConfig(
      clock: _parseSize(json['clock']),
      habits: _parseSize(json['habits']),
      calendar: _parseSize(json['calendar']),
      tasks: _parseSize(json['tasks']),
    );
  }

  /// Safely resolves a size enum value from a dynamic JSON token.
  static CardSize _parseSize(dynamic value) {
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return CardSize.values.firstWhere(
        (entry) => entry.name.toLowerCase() == normalized,
        orElse: () => CardSize.small,
      );
    }
    return CardSize.small;
  }
}

/// Manages reactive layout sizing state and persists modifications to JSON.
class CardLayoutNotifier extends Notifier<CardLayoutConfig> {
  @override
  CardLayoutConfig build() {
    _initializeFromDisk();
    return const CardLayoutConfig();
  }

  /// Asynchronously hydrates state from the `layout` database section.
  Future<void> _initializeFromDisk() async {
    final raw = await AppDatabase.readSection('layout');
    state = raw is Map<String, dynamic>
        ? CardLayoutConfig.fromJson(raw)
        : const CardLayoutConfig();
  }

  /// Sets an explicit size for the given card.
  void setCardSize(DashboardCardType type, CardSize size) {
    final updatedConfig = state.withSize(type, size);
    state = updatedConfig;
    AppDatabase.writeSection('layout', updatedConfig.toJson());
  }

  /// Reloads layout configuration from disk.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing layout state and configuration methods.
final cardLayoutProvider =
    NotifierProvider<CardLayoutNotifier, CardLayoutConfig>(
      CardLayoutNotifier.new,
    );

/// Represents a requested scroll target event for the dashboard deck.
class CardScrollRequest {
  final DashboardCardType card;
  final int timestamp;

  const CardScrollRequest({required this.card, required this.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardScrollRequest &&
          runtimeType == other.runtimeType &&
          card == other.card &&
          timestamp == other.timestamp;

  @override
  int get hashCode => card.hashCode ^ timestamp.hashCode;
}

/// Manages requested scroll target events for the dashboard deck.
class CardScrollRequestNotifier extends Notifier<CardScrollRequest?> {
  @override
  CardScrollRequest? build() => null;

  /// Requests the dashboard to scroll to the start of the designated card.
  void requestScroll(DashboardCardType card) {
    state = CardScrollRequest(
      card: card,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Riverpod provider exposing the latest card scroll request for the dashboard.
final cardScrollRequestProvider =
    NotifierProvider<CardScrollRequestNotifier, CardScrollRequest?>(
      CardScrollRequestNotifier.new,
    );
