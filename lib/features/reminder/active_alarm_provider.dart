import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/native/alarm_audio_gateway.dart';

/// Immutable snapshot of an actively ringing reminder alarm or preview.
@immutable
class ActiveAlarmState {
  /// Reminder whose occurrence triggered this alarm.
  final ReminderItem reminder;

  /// Scheduled or tapped occurrence timestamp that fired.
  final DateTime firedAt;

  /// Whether this alarm was launched from Settings preview mode (skips
  /// mutating persisted reminder state on dismiss/snooze).
  final bool isPreview;

  /// Default snooze duration offered by the ringing UI.
  final Duration defaultSnooze;

  /// Creates an [ActiveAlarmState].
  const ActiveAlarmState({
    required this.reminder,
    required this.firedAt,
    this.isPreview = false,
    this.defaultSnooze = const Duration(minutes: 10),
  });

  /// Serializes this ringing alarm snapshot for WebSocket and REST payloads.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reminder': reminder.toJson(),
      'fired_at': firedAt.toIso8601String(),
      'is_preview': isPreview,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveAlarmState &&
        other.reminder == reminder &&
        other.firedAt == firedAt &&
        other.isPreview == isPreview &&
        other.defaultSnooze == defaultSnooze;
  }

  @override
  int get hashCode => Object.hash(reminder, firedAt, isPreview, defaultSnooze);
}

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
