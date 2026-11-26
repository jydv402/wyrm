import 'package:flutter/foundation.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';

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
