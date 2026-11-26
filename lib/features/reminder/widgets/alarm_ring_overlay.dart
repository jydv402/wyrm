import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/widgets/alarm/alarm_backdrop.dart';
import 'package:wyrm_desk/features/reminder/widgets/alarm/alarm_layouts.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Root host overlaying [AlarmRingOverlay] over any active route when an alarm
/// is ringing (`activeAlarmProvider != null`).
class AlarmRingOverlayHost extends ConsumerWidget {
  /// Route content rendered beneath the overlay.
  final Widget child;

  const AlarmRingOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAlarm = ref.watch(activeAlarmProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (activeAlarm != null)
          Positioned.fill(child: AlarmRingOverlay(alarm: activeAlarm)),
      ],
    );
  }
}

/// Full-screen high-contrast Dusk Glass Plum alarm ringing surface.
class AlarmRingOverlay extends ConsumerStatefulWidget {
  /// Alarm snapshot currently ringing.
  final ActiveAlarmState alarm;

  const AlarmRingOverlay({super.key, required this.alarm});

  @override
  ConsumerState<AlarmRingOverlay> createState() => _AlarmRingOverlayState();
}

class _AlarmRingOverlayState extends ConsumerState<AlarmRingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled) {
      _entranceController.value = 1.0;
    } else if (_entranceController.status == AnimationStatus.dismissed) {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now =
        ref.watch(clockTimeProvider).value ?? ref.watch(clockProvider).now();
    final is24Hour = ref.watch(
      appSettingsProvider.select((settings) => settings.is24HourFormat),
    );
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final pulseHigh = !disableMotion && now.second.isEven;

    return PopScope(
      canPop: false,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        child: FadeTransition(
          opacity: _entranceController,
          child: Material(
            color: AppColors.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AlarmBackdrop(
                      pulseHigh: pulseHigh,
                      disableAnimations: disableMotion,
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720.0;
                        if (isWide) {
                          return AlarmWideLayout(
                            alarm: widget.alarm,
                            now: now,
                            is24Hour: is24Hour,
                            pulseHigh: pulseHigh,
                            disableAnimations: disableMotion,
                            onDismiss: _handleDismiss,
                            onSnooze: _handleSnooze,
                          );
                        }
                        return AlarmNarrowLayout(
                          alarm: widget.alarm,
                          now: now,
                          is24Hour: is24Hour,
                          pulseHigh: pulseHigh,
                          disableAnimations: disableMotion,
                          onDismiss: _handleDismiss,
                          onSnooze: _handleSnooze,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDismiss() {
    ref.read(activeAlarmProvider.notifier).dismissActive();
  }

  void _handleSnooze() {
    ref.read(activeAlarmProvider.notifier).snoozeActive();
  }
}
