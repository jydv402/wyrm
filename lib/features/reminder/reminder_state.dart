import 'package:flutter/foundation.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/features/reminder/reminder_filter.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

/// Immutable snapshot of reminder schedules, permission status, and view filter.
@immutable
class RemindersState {
  /// All persisted reminders in the store.
  final List<ReminderItem> items;

  /// Whether the initial disk load or an explicit reload has completed.
  final bool isLoaded;

  /// Current OS notification and exact-alarm permissions.
  final NotificationPermissionStatus permissions;

  /// Active list filter applied by [filteredItems].
  final ReminderFilter filter;

  /// Creates an immutable [RemindersState].
  const RemindersState({
    this.items = const <ReminderItem>[],
    this.isLoaded = false,
    this.permissions = const NotificationPermissionStatus(),
    this.filter = ReminderFilter.all,
  });

  /// All reminders currently enabled.
  List<ReminderItem> get enabledItems =>
      List<ReminderItem>.unmodifiable(items.where((item) => item.isEnabled));

  /// Resolves the next future fire instant for [item] strictly after [now].
  DateTime? nextFireAtFor(ReminderItem item, DateTime now) =>
      ReminderScheduler.nextFireAt(item, now: now);

  /// Returns the enabled reminder with the earliest upcoming fire time after
  /// [now], or `null` when no future occurrence exists.
  ReminderItem? nextUpcoming(DateTime now) {
    ReminderItem? bestItem;
    DateTime? bestFireAt;

    for (final item in items) {
      if (!item.isEnabled) continue;
      final fireAt = nextFireAtFor(item, now);
      if (fireAt == null) continue;
      if (bestFireAt == null ||
          fireAt.isBefore(bestFireAt) ||
          (fireAt.isAtSameMomentAs(bestFireAt) &&
              item.id.compareTo(bestItem!.id) < 0)) {
        bestItem = item;
        bestFireAt = fireAt;
      }
    }

    return bestItem;
  }

  /// Returns items matching [filter], sorted with earliest upcoming occurrences
  /// first and inactive/disabled items afterward.
  List<ReminderItem> filteredItems(DateTime now) {
    final matching = items.where((item) {
      switch (filter) {
        case ReminderFilter.all:
          return true;
        case ReminderFilter.active:
          return item.isEnabled;
        case ReminderFilter.recurring:
          return item.recurrence != ReminderRecurrence.once;
      }
    }).toList();

    final cachedFireAt = <String, DateTime?>{
      for (final item in matching) item.id: nextFireAtFor(item, now),
    };

    matching.sort((a, b) {
      final fireA = cachedFireAt[a.id];
      final fireB = cachedFireAt[b.id];

      if (fireA != null && fireB != null) {
        final fireOrder = fireA.compareTo(fireB);
        if (fireOrder != 0) return fireOrder;
      } else if (fireA != null) {
        return -1;
      } else if (fireB != null) {
        return 1;
      }

      if (a.isEnabled != b.isEnabled) {
        return a.isEnabled ? -1 : 1;
      }

      final scheduledOrder = a.scheduledAt.compareTo(b.scheduledAt);
      if (scheduledOrder != 0) return scheduledOrder;

      final createdOrder = a.createdAt.compareTo(b.createdAt);
      if (createdOrder != 0) return createdOrder;

      return a.id.compareTo(b.id);
    });

    return List<ReminderItem>.unmodifiable(matching);
  }

  /// Returns a copy of this state with specified overrides.
  RemindersState copyWith({
    List<ReminderItem>? items,
    bool? isLoaded,
    NotificationPermissionStatus? permissions,
    ReminderFilter? filter,
  }) {
    return RemindersState(
      items: items != null
          ? List<ReminderItem>.unmodifiable(items)
          : this.items,
      isLoaded: isLoaded ?? this.isLoaded,
      permissions: permissions ?? this.permissions,
      filter: filter ?? this.filter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RemindersState &&
        listEquals(other.items, items) &&
        other.isLoaded == isLoaded &&
        other.permissions == permissions &&
        other.filter == filter;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), isLoaded, permissions, filter);
}
