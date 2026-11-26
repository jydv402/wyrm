import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_state.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/native/alarm_audio_gateway.dart';

export 'package:wyrm_desk/features/reminder/active_alarm_state.dart';

/// Manages the currently ringing full-screen alarm and native chime/wake state.
class ActiveAlarmNotifier extends Notifier<ActiveAlarmState?> {
  AlarmAudioGateway get _audioGateway => ref.read(alarmAudioGatewayProvider);

  @override
  ActiveAlarmState? build() => null;

  /// Raises [reminder] at [firedAt], waking the screen and starting the alarm
  /// chime via [AlarmAudioGateway].
  Future<void> triggerAlarm(
    ReminderItem reminder,
    DateTime firedAt, {
    bool isPreview = false,
  }) async {
    final current = state;
    if (current != null &&
        current.reminder.id == reminder.id &&
        current.firedAt == firedAt &&
        current.isPreview == isPreview) {
      return;
    }

    state = ActiveAlarmState(
      reminder: reminder,
      firedAt: firedAt,
      isPreview: isPreview,
    );

    await _audioGateway.setWakeScreen(true);
    await _audioGateway.startChime();
  }

  /// Stops alarm audio/wake flags, clears the overlay immediately, and updates
  /// reminder persistence unless the active alarm is a preview.
  Future<void> dismissActive() async {
    final active = state;
    if (active == null) return;

    state = null;

    await _audioGateway.stopChime();
    await _audioGateway.setWakeScreen(false);

    if (!active.isPreview && ref.mounted) {
      await ref
          .read(remindersProvider.notifier)
          .dismissReminder(active.reminder.id, firedAt: active.firedAt);
    }
  }

  /// Stops alarm audio/wake flags, clears the overlay immediately, and snoozes
  /// the reminder unless the active alarm is a preview.
  Future<void> snoozeActive([Duration? duration]) async {
    final active = state;
    if (active == null) return;

    final snoozeDuration = duration ?? active.defaultSnooze;
    state = null;

    await _audioGateway.stopChime();
    await _audioGateway.setWakeScreen(false);

    if (!active.isPreview && ref.mounted) {
      await ref
          .read(remindersProvider.notifier)
          .snoozeReminder(active.reminder.id, duration: snoozeDuration);
    }
  }
}

/// Riverpod provider exposing the currently ringing alarm, or `null` when idle.
final activeAlarmProvider =
    NotifierProvider<ActiveAlarmNotifier, ActiveAlarmState?>(
      ActiveAlarmNotifier.new,
    );
