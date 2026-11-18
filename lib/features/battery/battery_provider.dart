import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/battery/battery_state.dart';

/// Contract for battery operations to allow easy mocking and testing.
abstract class BatteryService {
  Future<int> getBatteryLevel();
  Future<BatteryState> getBatteryState();
  Stream<BatteryState> get onBatteryStateChanged;
}

/// Production implementation backed by [Battery].
class SystemBatteryService implements BatteryService {
  final Battery _battery;

  SystemBatteryService([Battery? battery]) : _battery = battery ?? Battery();

  @override
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  @override
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (_) {
      return BatteryState.unknown;
    }
  }

  @override
  Stream<BatteryState> get onBatteryStateChanged {
    try {
      return _battery.onBatteryStateChanged;
    } catch (_) {
      return const Stream.empty();
    }
  }
}

/// Provider exposing the [BatteryService] singleton.
final batteryServiceProvider = Provider<BatteryService>((ref) {
  return SystemBatteryService();
});

/// Reactive stream provider tracking battery level and state changes.
final batteryInfoProvider = StreamProvider.autoDispose<BatteryInfo>((
  ref,
) async* {
  final service = ref.watch(batteryServiceProvider);

  Future<BatteryInfo> fetchCurrent() async {
    try {
      final level = await service.getBatteryLevel();
      final state = await service.getBatteryState();
      return BatteryInfo(level: level, state: state);
    } catch (_) {
      return const BatteryInfo(level: 100, state: BatteryState.unknown);
    }
  }

  // Yield initial battery status immediately
  yield await fetchCurrent();

  final controller = StreamController<BatteryInfo>();

  // Periodically refresh battery level (e.g. every 60 seconds)
  final timer = Timer.periodic(const Duration(minutes: 1), (_) async {
    if (!controller.isClosed) {
      controller.add(await fetchCurrent());
    }
  });

  // Re-fetch level immediately upon charger plug/unplug events
  final subscription = service.onBatteryStateChanged.listen((_) async {
    if (!controller.isClosed) {
      controller.add(await fetchCurrent());
    }
  });

  ref.onDispose(() {
    timer.cancel();
    subscription.cancel();
    controller.close();
  });

  yield* controller.stream;
});
