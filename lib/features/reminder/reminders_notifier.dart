import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/repositories/reminder_repository.dart';
import 'package:wyrm_desk/features/reminder/reminder_filter.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

/// Manages reactive reminder state, repository persistence, permissions, and
/// OS notification synchronization.
///
/// Every mutation goes through [_commitMutation], which serializes disk writes
/// and OS reconciliation on one chain so a slow sync can never overwrite a
/// newer snapshot. [_mutationEpoch] invalidates in-flight disk loads that a
/// mutation or reload has superseded.
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

    // A mutation landed while loading: keep its items but still record that the
    // store is hydrated and expose the fresh permission snapshot.
    if (_mutationEpoch != epoch) {
      state = state.copyWith(isLoaded: true, permissions: permissions);
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
    if (!_contains(reminder.id)) return;
    final updated = state.items
        .map((item) => item.id == reminder.id ? reminder : item)
        .toList();
    await _commitMutation(updated);
  }

  /// Removes the reminder matching [id] and cancels its scheduled OS alarms.
  Future<void> deleteReminder(String id) async {
    if (!_contains(id)) return;
    await _commitMutation(state.items.where((item) => item.id != id).toList());
  }

  /// Toggles or explicitly sets [isEnabled] on the reminder matching [id].
  Future<void> toggleReminder(String id, [bool? isEnabled]) async {
    if (!_contains(id)) return;
    await _commitMutation(
      state.items.map((item) {
        if (item.id != id) return item;
        final nextEnabled = isEnabled ?? !item.isEnabled;
        return item.copyWith(
          isEnabled: nextEnabled,
          clearSnoozedUntil: !nextEnabled,
        );
      }).toList(),
    );
  }

  /// Marks an occurrence as dismissed: disables one-time reminders and keeps
  /// repeating reminders enabled for their next occurrence.
  Future<void> dismissReminder(String id, {DateTime? firedAt}) async {
    if (!_contains(id)) return;
    final effectiveFiredAt = firedAt ?? _clock.now();
    await _commitMutation(
      state.items.map((item) {
        if (item.id != id) return item;
        return item.copyWith(
          isEnabled: item.recurrence == ReminderRecurrence.once
              ? false
              : item.isEnabled,
          clearSnoozedUntil: true,
          lastTriggeredAt: effectiveFiredAt,
        );
      }).toList(),
    );
  }

  /// Snoozes the reminder matching [id] for [duration] from the current clock.
  Future<void> snoozeReminder(
    String id, {
    Duration duration = const Duration(minutes: 10),
  }) async {
    if (!_contains(id)) return;
    final now = _clock.now();
    await _commitMutation(
      state.items.map((item) {
        if (item.id != id) return item;
        return item.copyWith(
          isEnabled: true,
          snoozedUntil: now.add(duration),
          lastTriggeredAt: item.lastTriggeredAt ?? now,
        );
      }).toList(),
    );
  }

  /// Records [firedAt] on [id] before raising the alarm overlay so consecutive
  /// clock ticks cannot trigger the same occurrence twice.
  Future<void> markTriggered(String id, DateTime firedAt) async {
    final item = _findById(id);
    if (item == null) return;
    final lastTriggeredAt = item.lastTriggeredAt;
    if (lastTriggeredAt != null && !lastTriggeredAt.isBefore(firedAt)) return;

    await _commitMutation(
      state.items
          .map(
            (entry) => entry.id == id
                ? entry.copyWith(lastTriggeredAt: firedAt)
                : entry,
          )
          .toList(),
    );
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

    // Wait for any in-flight local save to land before re-reading so an active
    // mutation cannot be overwritten or race behind this reload.
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

  bool _contains(String id) => state.items.any((item) => item.id == id);

  ReminderItem? _findById(String id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
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
