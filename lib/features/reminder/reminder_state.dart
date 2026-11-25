import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/data/repositories/reminder_repository.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

/// View filter applied to the reminders list in dashboard and editor surfaces.
enum ReminderFilter {
  /// Show all reminders regardless of status or recurrence.
  all,

  /// Show only enabled reminders.
  active,

  /// Show only repeating reminders (`daily`, `weekdays`, `custom`).
  recurring;

  /// Human-readable display label for filter pills.
  String get label {
    switch (this) {
      case ReminderFilter.all:
        return 'All';
      case ReminderFilter.active:
        return 'Active';
      case ReminderFilter.recurring:
        return 'Recurring';
    }
  }
}

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

/// Manages reactive reminder state, repository persistence, permissions, and
/// OS notification synchronization.
class RemindersNotifier extends Notifier<RemindersState> {
  ReminderRepository get _repository => ref.read(reminderRepositoryProvider);
  NotificationGateway get _gateway => ref.read(notificationGatewayProvider);
  Clock get _clock => ref.read(clockProvider);

  Future<void> _initFuture = Future<void>.value();
  Future<void> _persistChain = Future<void>.value();
  int _mutationEpoch = 0;

  /// Future that completes once the initial disk hydration finishes.
  Future<void> get initialized => _initFuture;

  @override
  RemindersState build() {
    _initFuture = _initializeFromDisk();
    return const RemindersState();
  }

  Future<void> _initializeFromDisk() async {
    final epoch = _mutationEpoch;
    final loaded = await _repository.loadReminders();
    if (!ref.mounted) return;
    final permissions = await _gateway.permissionStatus();
    if (!ref.mounted) return;

    if (_mutationEpoch != epoch) {
      if (!state.isLoaded || state.permissions != permissions) {
        state = state.copyWith(isLoaded: true, permissions: permissions);
      }
      return;
    }

    final snapshot = List<ReminderItem>.unmodifiable(loaded);
    state = state.copyWith(
      items: snapshot,
      isLoaded: true,
      permissions: permissions,
    );

    await _enqueueTask(() async {
      if (!ref.mounted || _mutationEpoch != epoch) return;
      await syncNotifications(
        gateway: _gateway,
        reminders: snapshot,
        now: _clock.now(),
      );
    });
  }

  /// Creates and persists a new reminder using the injected [clockProvider].
  Future<ReminderItem> addReminder({
    required String title,
    required DateTime scheduledAt,
    ReminderRecurrence recurrence = ReminderRecurrence.once,
    List<int> customWeekdays = const <int>[],
    bool isEnabled = true,
  }) async {
    final now = _clock.now();
    final item = ReminderItem(
      id: _generateId(now),
      title: title.trim(),
      scheduledAt: scheduledAt,
      recurrence: recurrence,
      customWeekdays: ReminderItem.normalizeWeekdays(customWeekdays),
      isEnabled: isEnabled,
      createdAt: now,
    );
    await addExistingReminder(item);
    return item;
  }

  /// Adds (or replaces if the same ID exists) a pre-built [ReminderItem].
  Future<void> addExistingReminder(ReminderItem reminder) async {
    final exists = state.items.any((item) => item.id == reminder.id);
    final updated = exists
        ? state.items
              .map((item) => item.id == reminder.id ? reminder : item)
              .toList()
        : <ReminderItem>[...state.items, reminder];
    await _commitMutation(updated);
  }

  /// Replaces an existing reminder matching [reminder.id] and resyncs schedules.
  Future<void> editReminder(ReminderItem reminder) async {
    if (!state.items.any((item) => item.id == reminder.id)) return;
    final updated = state.items
        .map((item) => item.id == reminder.id ? reminder : item)
        .toList();
    await _commitMutation(updated);
  }

  /// Removes the reminder matching [id] and cancels its scheduled OS alarms.
  Future<void> deleteReminder(String id) async {
    if (!state.items.any((item) => item.id == id)) return;
    final updated = state.items.where((item) => item.id != id).toList();
    await _commitMutation(updated);
  }

  /// Toggles or explicitly sets [isEnabled] on the reminder matching [id].
  Future<void> toggleReminder(String id, [bool? isEnabled]) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final updated = state.items.map((item) {
      if (item.id != id) return item;
      final nextEnabled = isEnabled ?? !item.isEnabled;
      return item.copyWith(
        isEnabled: nextEnabled,
        clearSnoozedUntil: !nextEnabled,
      );
    }).toList();
    await _commitMutation(updated);
  }

  /// Marks an occurrence as dismissed: disables one-time reminders and keeps
  /// repeating reminders enabled for their next occurrence.
  Future<void> dismissReminder(String id, {DateTime? firedAt}) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final now = _clock.now();
    final effectiveFiredAt = firedAt ?? now;
    final updated = state.items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(
        isEnabled: item.recurrence == ReminderRecurrence.once
            ? false
            : item.isEnabled,
        clearSnoozedUntil: true,
        lastTriggeredAt: effectiveFiredAt,
      );
    }).toList();
    await _commitMutation(updated);
  }

  /// Snoozes the reminder matching [id] for [duration] from the current clock.
  Future<void> snoozeReminder(
    String id, {
    Duration duration = const Duration(minutes: 10),
  }) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final now = _clock.now();
    final snoozeTarget = now.add(duration);
    final updated = state.items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(
        isEnabled: true,
        snoozedUntil: snoozeTarget,
        lastTriggeredAt: item.lastTriggeredAt ?? now,
      );
    }).toList();
    await _commitMutation(updated);
  }

  /// Records [firedAt] on [id] before raising the alarm overlay so consecutive
  /// clock ticks cannot trigger the same occurrence twice.
  Future<void> markTriggered(String id, DateTime firedAt) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final current = state.items[index];
    if (current.lastTriggeredAt != null &&
        !current.lastTriggeredAt!.isBefore(firedAt)) {
      return;
    }

    final updated = state.items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(lastTriggeredAt: firedAt);
    }).toList();
    await _commitMutation(updated);
  }

  /// Updates the active view filter without writing to disk.
  void setFilter(ReminderFilter filter) {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter);
  }

  /// Reloads reminders from disk and reconciles OS schedules (wiping all prior
  /// OS schedules first when [fromBackupRestore] is `true`).
  Future<void> reloadFromDisk({bool fromBackupRestore = false}) async {
    final epoch = ++_mutationEpoch;
    // Wait for any in-flight local save to land on disk before re-reading so
    // an active mutation cannot be overwritten or race behind this reload.
    await _persistChain;
    if (!ref.mounted || _mutationEpoch != epoch) return;

    final loaded = await _repository.loadReminders();
    if (!ref.mounted || _mutationEpoch != epoch) return;

    final permissions = await _gateway.permissionStatus();
    if (!ref.mounted || _mutationEpoch != epoch) return;

    final snapshot = List<ReminderItem>.unmodifiable(loaded);
    state = state.copyWith(
      items: snapshot,
      isLoaded: true,
      permissions: permissions,
    );

    await _enqueueTask(() async {
      if (!ref.mounted) return;
      if (!fromBackupRestore && _mutationEpoch != epoch) return;
      final now = _clock.now();
      if (fromBackupRestore) {
        await rebuildNotificationsAfterRestore(
          gateway: _gateway,
          reminders: snapshot,
          now: now,
        );
      } else {
        await syncNotifications(
          gateway: _gateway,
          reminders: snapshot,
          now: now,
        );
      }
    });
  }

  /// Queries current OS notification and exact-alarm permission flags.
  Future<void> refreshPermissions() async {
    final permissions = await _gateway.permissionStatus();
    if (!ref.mounted) return;
    state = state.copyWith(permissions: permissions);
  }

  /// Prompts for notification permission and refreshes stored status.
  Future<bool> requestNotificationsPermission() async {
    final granted = await _gateway.requestNotificationsPermission();
    if (!ref.mounted) return granted;

    final permissions = await _gateway.permissionStatus();
    if (!ref.mounted) return granted;

    state = state.copyWith(permissions: permissions);
    await _enqueueTask(() async {
      if (!ref.mounted) return;
      await syncNotifications(
        gateway: _gateway,
        reminders: state.items,
        now: _clock.now(),
      );
    });
    return granted;
  }

  /// Prompts for exact-alarm permission and upgrades scheduled notifications if
  /// exact mode changed.
  Future<bool> requestExactAlarmsPermission() async {
    final wasExact = state.permissions.exactAlarmsAllowed;
    final granted = await _gateway.requestExactAlarmsPermission();
    if (!ref.mounted) return granted;

    final permissions = await _gateway.permissionStatus();
    if (!ref.mounted) return granted;

    state = state.copyWith(permissions: permissions);
    if (permissions.exactAlarmsAllowed != wasExact) {
      await _enqueueTask(() async {
        if (!ref.mounted) return;
        await syncNotifications(
          gateway: _gateway,
          reminders: state.items,
          now: _clock.now(),
          forceReschedule: true,
        );
      });
    }
    return granted;
  }

  /// Opens system notification settings and refreshes permission status.
  Future<bool> openSystemNotificationSettings() async {
    final opened = await _gateway.openSystemNotificationSettings();
    if (!ref.mounted) return opened;
    await refreshPermissions();
    return opened;
  }

  Future<void> _commitMutation(List<ReminderItem> updated) async {
    final snapshot = List<ReminderItem>.unmodifiable(updated);
    final epoch = ++_mutationEpoch;
    state = state.copyWith(items: snapshot, isLoaded: true);

    await _enqueueTask(() async {
      await _repository.saveReminders(snapshot);
      if (!ref.mounted || _mutationEpoch != epoch) return;
      await syncNotifications(
        gateway: _gateway,
        reminders: snapshot,
        now: _clock.now(),
      );
    });
  }

  Future<void> _enqueueTask(Future<void> Function() task) {
    final next = _persistChain.then((_) => task());
    _persistChain = next.catchError((Object _) {});
    return next;
  }

  String _generateId(DateTime now) {
    final existingIds = state.items.map((item) => item.id).toSet();
    final base = 'rem_${now.microsecondsSinceEpoch}';
    if (!existingIds.contains(base)) return base;
    var suffix = 1;
    while (existingIds.contains('${base}_$suffix')) {
      suffix++;
    }
    return '${base}_$suffix';
  }
}

/// Global provider exposing reactive reminder schedules and operations.
final remindersProvider = NotifierProvider<RemindersNotifier, RemindersState>(
  RemindersNotifier.new,
);
