import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_state.dart';
import 'package:wyrm_desk/features/reminder/widgets/alarm/alarm_action_button.dart';
import 'package:wyrm_desk/features/reminder/widgets/alarm/alarm_reminder_card.dart';
import 'package:wyrm_desk/features/reminder/widgets/alarm/alarm_status_header.dart';

/// Two-pane alarm layout used on wide (tablet) screens.
class AlarmWideLayout extends StatelessWidget {
  /// Alarm snapshot being displayed.
  final ActiveAlarmState alarm;

  /// Current wall-clock instant.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Whether the status dot is at full opacity.
  final bool pulseHigh;

  /// Whether animations are disabled.
  final bool disableAnimations;

  /// Stops the alarm and completes the occurrence.
  final VoidCallback onDismiss;

  /// Stops the alarm and reschedules it.
  final VoidCallback onSnooze;

  const AlarmWideLayout({
    super.key,
    required this.alarm,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24.0,
      children: [
        Expanded(
          flex: 42,
          child: AlarmControlZone(
            alarm: alarm,
            now: now,
            is24Hour: is24Hour,
            pulseHigh: pulseHigh,
            disableAnimations: disableAnimations,
            onDismiss: onDismiss,
            onSnooze: onSnooze,
          ),
        ),
        Expanded(
          flex: 58,
          child: AlarmReminderCard(
            alarm: alarm,
            is24Hour: is24Hour,
            titleFontSize: 48.0,
          ),
        ),
      ],
    );
  }
}

/// Single-column alarm layout used on narrow (phone) screens.
class AlarmNarrowLayout extends StatelessWidget {
  /// Alarm snapshot being displayed.
  final ActiveAlarmState alarm;

  /// Current wall-clock instant.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Whether the status dot is at full opacity.
  final bool pulseHigh;

  /// Whether animations are disabled.
  final bool disableAnimations;

  /// Stops the alarm and completes the occurrence.
  final VoidCallback onDismiss;

  /// Stops the alarm and reschedules it.
  final VoidCallback onSnooze;

  const AlarmNarrowLayout({
    super.key,
    required this.alarm,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20.0,
        children: [
          AlarmStatusHeader(
            now: now,
            is24Hour: is24Hour,
            pulseHigh: pulseHigh,
            disableAnimations: disableAnimations,
          ),
          AlarmReminderCard(
            alarm: alarm,
            is24Hour: is24Hour,
            titleFontSize: 42.0,
          ),
          AlarmButtonsColumn(
            snoozeMinutes: alarm.defaultSnooze.inMinutes,
            onDismiss: onDismiss,
            onSnooze: onSnooze,
          ),
        ],
      ),
    );
  }
}

/// Status header above the Cancel/Snooze buttons in the wide layout.
class AlarmControlZone extends StatelessWidget {
  /// Alarm snapshot being displayed.
  final ActiveAlarmState alarm;

  /// Current wall-clock instant.
  final DateTime now;

  /// Whether to render times in 24-hour format.
  final bool is24Hour;

  /// Whether the status dot is at full opacity.
  final bool pulseHigh;

  /// Whether animations are disabled.
  final bool disableAnimations;

  /// Stops the alarm and completes the occurrence.
  final VoidCallback onDismiss;

  /// Stops the alarm and reschedules it.
  final VoidCallback onSnooze;

  const AlarmControlZone({
    super.key,
    required this.alarm,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 20.0,
      children: [
        AlarmStatusHeader(
          now: now,
          is24Hour: is24Hour,
          pulseHigh: pulseHigh,
          disableAnimations: disableAnimations,
        ),
        AlarmButtonsColumn(
          snoozeMinutes: alarm.defaultSnooze.inMinutes,
          onDismiss: onDismiss,
          onSnooze: onSnooze,
        ),
      ],
    );
  }
}
