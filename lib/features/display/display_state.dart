import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';

import 'display_service.dart';

/// Immutable snapshot of the tablet's own display state (panel brightness).
///
/// This models the physical screen of the device running WYRM Desk, controlled by the
/// web remote. It is intentionally separate from any OS lock or power state.
class DisplayState {
  /// Panel brightness, clamped between [minBrightness] and 1.0 (100%).
  final double brightness;

  /// Lowest selectable brightness so the panel stays readable.
  static const double minBrightness = 0.05;

  const DisplayState({
    this.brightness = 1.0,
  });

  /// Returns a copy of this state with the specified overrides.
  DisplayState copyWith({
    double? brightness,
  }) {
    return DisplayState(
      brightness: brightness ?? this.brightness,
    );
  }

  /// Serializes to the on-disk JSON shape (snake_case keys).
  Map<String, dynamic> toJson() {
    return {
      'brightness': brightness,
    };
  }

  /// Serializes to the web-remote wire shape (camelCase keys).
  Map<String, dynamic> toWireJson() {
    return {
      'brightness': brightness,
    };
  }

  /// Deserializes from the on-disk JSON shape.
  factory DisplayState.fromJson(Map<String, dynamic> json) {
    final rawBrightness = (json['brightness'] as num?)?.toDouble() ?? 1.0;
    return DisplayState(
      brightness: rawBrightness.clamp(minBrightness, 1.0),
    );
  }
}

/// Manages reactive display state, applying every change to the native panel.
class DisplayNotifier extends Notifier<DisplayState> {
  @override
  DisplayState build() {
    _initializeFromDisk();
    return const DisplayState();
  }

  /// Hydrates persisted brightness from the `display` database section.
  Future<void> _initializeFromDisk() async {
    final raw = await AppDatabase.readSection('display');
    state = raw is Map<String, dynamic>
        ? DisplayState.fromJson(raw)
        : const DisplayState();
    _applyToDevice();
  }

  /// Sets the panel brightness, clamped to a usable range, and persists it.
  void setBrightness(double value) {
    final clamped = value.clamp(DisplayState.minBrightness, 1.0);
    if (state.brightness == clamped) return;
    state = state.copyWith(brightness: clamped);
    AppDatabase.writeSection('display', state.toJson());
    _applyToDevice();
  }

  /// Pushes the current state to the native host window.
  void _applyToDevice() {
    DisplayService.apply(brightness: state.brightness);
  }

  /// Reloads display configuration from disk and re-applies brightness.
  Future<void> reloadFromDisk() async {
    await _initializeFromDisk();
  }
}

/// Riverpod provider exposing the tablet display state.
final displayProvider = NotifierProvider<DisplayNotifier, DisplayState>(
  DisplayNotifier.new,
);
