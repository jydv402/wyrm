import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/app_database.dart';

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

  /// Returns the next size in the cycle progression.
  CardSize get next {
    switch (this) {
      case CardSize.small:
        return CardSize.medium;
      case CardSize.medium:
        return CardSize.fullscreen;
      case CardSize.fullscreen:
        return CardSize.nightstand;
      case CardSize.nightstand:
        return CardSize.small;
    }
  }

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
  tasks,
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

/// Persists and loads layout configuration via unified AppDatabase storage.
class CardLayoutStorage {
  /// Reads and parses the stored JSON configuration from unified AppDatabase.
  static Future<CardLayoutConfig> loadConfig() async {
    return await AppDatabase.loadLayout();
  }

  /// Writes the current layout configuration to unified AppDatabase storage.
  static Future<void> saveConfig(CardLayoutConfig config) async {
    await AppDatabase.saveLayout(config);
  }
}

/// Manages reactive layout sizing state and persists modifications to JSON.
class CardLayoutNotifier extends Notifier<CardLayoutConfig> {
  @override
  CardLayoutConfig build() {
    _initializeFromDisk();
    return const CardLayoutConfig();
  }

  /// Asynchronously hydrates the state from local JSON storage.
  Future<void> _initializeFromDisk() async {
    final loaded = await CardLayoutStorage.loadConfig();
    state = loaded;
  }

  /// Advances the size of the given card to the next progression tier.
  void cycleCardSize(DashboardCardType type) {
    final currentSize = state.sizeFor(type);
    final nextSize = currentSize.next;
    final updatedConfig = state.withSize(type, nextSize);
    state = updatedConfig;
    CardLayoutStorage.saveConfig(updatedConfig);
  }

  /// Sets an explicit size for the given card.
  void setCardSize(DashboardCardType type, CardSize size) {
    final updatedConfig = state.withSize(type, size);
    state = updatedConfig;
    CardLayoutStorage.saveConfig(updatedConfig);
  }

  /// Resets all cards back to the default small layout.
  void restoreDefaultLayout() {
    const defaultConfig = CardLayoutConfig();
    state = defaultConfig;
    CardLayoutStorage.saveConfig(defaultConfig);
  }
}

/// Riverpod provider exposing layout state and configuration methods.
final cardLayoutProvider =
    NotifierProvider<CardLayoutNotifier, CardLayoutConfig>(
  CardLayoutNotifier.new,
);
