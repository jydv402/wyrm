import 'package:battery_plus/battery_plus.dart';

/// Represents the current battery state and charge percentage.
class BatteryInfo {
  /// Battery charge level from 0 to 100.
  final int level;

  /// Current state reported by the OS (charging, discharging, full, etc.).
  final BatteryState state;

  const BatteryInfo({required this.level, required this.state});

  /// Whether the device is actively charging or connected to external power.
  bool get isCharging =>
      state == BatteryState.charging ||
      state == BatteryState.connectedNotCharging ||
      (state == BatteryState.full && level == 100);

  /// Whether battery level is critically low (< 20%) while not charging.
  bool get isLowBattery => level < 20 && !isCharging;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryInfo &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          state == other.state;

  @override
  int get hashCode => Object.hash(level, state);

  @override
  String toString() => 'BatteryInfo(level: $level%, state: $state)';
}
