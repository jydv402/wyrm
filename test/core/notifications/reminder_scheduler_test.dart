import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/core/notifications/deterministic_id.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';

void main() {
  group('ReminderRecurrence & ReminderItem', () {
    test('ReminderRecurrence exposes label, apiName, and tolerant parsing', () {
      expect(ReminderRecurrence.once.label, 'Once');
      expect(ReminderRecurrence.daily.label, 'Daily');
      expect(ReminderRecurrence.weekdays.label, 'Weekdays');
      expect(ReminderRecurrence.custom.label, 'Custom');

      expect(ReminderRecurrence.once.apiName, 'once');
      expect(ReminderRecurrence.daily.apiName, 'daily');
      expect(ReminderRecurrence.weekdays.apiName, 'weekdays');
      expect(ReminderRecurrence.custom.apiName, 'custom');

      expect(ReminderRecurrence.fromString('once'), ReminderRecurrence.once);
      expect(
        ReminderRecurrence.fromString('one-time'),
        ReminderRecurrence.once,
      );
      expect(ReminderRecurrence.fromString('DAILY'), ReminderRecurrence.daily);
      expect(
        ReminderRecurrence.fromString('mon_fri'),
        ReminderRecurrence.weekdays,
      );
      expect(
        ReminderRecurrence.fromString('custom'),
        ReminderRecurrence.custom,
      );
      expect(
        ReminderRecurrence.fromString(ReminderRecurrence.weekdays),
        ReminderRecurrence.weekdays,
      );
      expect(ReminderRecurrence.fromString(null), ReminderRecurrence.once);
      expect(ReminderRecurrence.fromString('unknown'), ReminderRecurrence.once);
    });

    test('toJson and fromJson support snake_case and camelCase aliases', () {
      final scheduled = DateTime(2026, 6, 15, 7, 30);
      final snoozed = DateTime(2026, 6, 15, 7, 40);
      final lastTriggered = DateTime(2026, 6, 14, 7, 30);
      final created = DateTime(2026, 6, 1, 9, 0);

      final item = ReminderItem(
        id: 'rem-1',
        title: 'Take vitamins',
        scheduledAt: scheduled,
        recurrence: ReminderRecurrence.custom,
        customWeekdays: const [1, 3, 5],
        isEnabled: true,
        snoozedUntil: snoozed,
        lastTriggeredAt: lastTriggered,
        createdAt: created,
      );

      final json = item.toJson();
      expect(json['id'], 'rem-1');
      expect(json['title'], 'Take vitamins');
      expect(json['scheduled_at'], scheduled.toIso8601String());
      expect(json['recurrence'], 'custom');
      expect(json['custom_weekdays'], [1, 3, 5]);
      expect(json['is_enabled'], true);
      expect(json['snoozed_until'], snoozed.toIso8601String());
      expect(json['last_triggered_at'], lastTriggered.toIso8601String());
      expect(json['created_at'], created.toIso8601String());

      expect(ReminderItem.fromJson(json), item);

      final camelParsed = ReminderItem.fromJson(<String, dynamic>{
        'id': 'rem-1',
        'title': 'Take vitamins',
        'scheduledAt': scheduled.toIso8601String(),
        'recurrence': 'custom',
        'customWeekdays': [5, 1, 3, 1, 9, 0],
        'isEnabled': true,
        'snoozedUntil': snoozed.toIso8601String(),
        'lastTriggeredAt': lastTriggered.toIso8601String(),
        'createdAt': created.toIso8601String(),
      });
      expect(camelParsed, item);
      expect(camelParsed.customWeekdays, [1, 3, 5]);
    });

    test('copyWith clears nullable timestamps when requested', () {
      final item = ReminderItem(
        id: 'rem-2',
        title: 'Stretch',
        scheduledAt: DateTime(2026, 6, 15, 10, 0),
        snoozedUntil: DateTime(2026, 6, 15, 10, 10),
        lastTriggeredAt: DateTime(2026, 6, 15, 10, 0),
        createdAt: DateTime(2026, 6, 1, 8, 0),
      );

      final cleared = item.copyWith(
        clearSnoozedUntil: true,
        clearLastTriggeredAt: true,
        customWeekdays: [7, 2, 2, 4],
      );
      expect(cleared.snoozedUntil, isNull);
      expect(cleared.lastTriggeredAt, isNull);
      expect(cleared.customWeekdays, [2, 4, 7]);
    });
  });

  group('deterministicNotificationId', () {
    test('produces stable positive 31-bit non-zero Android ints', () {
      final fireAt = DateTime(2026, 7, 1, 8, 30);
      final idA = deterministicNotificationId('rem-abc', fireAt);
      final idB = deterministicNotificationId('rem-abc', fireAt);
      expect(idA, idB);
      expect(idA, greaterThan(0));
      expect(idA, lessThanOrEqualTo(0x7FFFFFFF));

      final editedFireAt = DateTime(2026, 7, 1, 14, 0);
      final editedId = deterministicNotificationId('rem-abc', editedFireAt);
      expect(editedId, isNot(idA));

      final otherSlotId = deterministicNotificationId(
        'rem-abc',
        fireAt,
        slotOffset: 1,
      );
      expect(otherSlotId, isNot(idA));
    });

    test('produces distinct IDs across 200 reminder/date combinations', () {
      final ids = <int>{};
      for (var i = 0; i < 200; i++) {
        final dt = DateTime(2026, 1, 1, 6, 0).add(Duration(minutes: i * 15));
        final id = deterministicNotificationId('reminder-$i', dt);
        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
        ids.add(id);
      }
      expect(ids.length, 200);
    });
  });

  group('ReminderScheduler.currentDueOccurrence & isDueNow', () {
    test('disabled reminder never fires', () {
      final now = DateTime(2026, 6, 15, 9, 0);
      final item = ReminderItem(
        id: 'disabled',
        title: 'Disabled',
        scheduledAt: now,
        isEnabled: false,
        createdAt: now.subtract(const Duration(days: 1)),
      );
      expect(ReminderScheduler.currentDueOccurrence(item, now: now), isNull);
      expect(ReminderScheduler.isDueNow(item, now: now), isFalse);
    });

    test('once reminder fires at or after scheduledAt until triggered', () {
      final target = DateTime(2026, 6, 15, 9, 0);
      final item = ReminderItem(
        id: 'once-1',
        title: 'Standup',
        scheduledAt: target,
        recurrence: ReminderRecurrence.once,
        createdAt: DateTime(2026, 6, 14, 9, 0),
      );

      expect(
        ReminderScheduler.currentDueOccurrence(
          item,
          now: target.subtract(const Duration(seconds: 1)),
        ),
        isNull,
      );
      expect(ReminderScheduler.currentDueOccurrence(item, now: target), target);
      expect(
        ReminderScheduler.currentDueOccurrence(
          item,
          now: target.add(const Duration(seconds: 45)),
        ),
        target,
      );

      final triggered = item.copyWith(lastTriggeredAt: target);
      expect(
        ReminderScheduler.currentDueOccurrence(
          triggered,
          now: target.add(const Duration(seconds: 30)),
        ),
        isNull,
      );
    });

    test('daily reminder respects catchUpWindow and prevents re-fire', () {
      final created = DateTime(2026, 6, 1, 7, 0);
      final item = ReminderItem(
        id: 'daily-1',
        title: 'Morning stretch',
        scheduledAt: DateTime(2026, 6, 1, 7, 30),
        recurrence: ReminderRecurrence.daily,
        createdAt: created,
      );

      final exactTick = DateTime(2026, 6, 15, 7, 30);
      expect(
        ReminderScheduler.currentDueOccurrence(item, now: exactTick),
        exactTick,
      );
      expect(
        ReminderScheduler.currentDueOccurrence(
          item,
          now: DateTime(2026, 6, 15, 7, 32),
        ),
        exactTick,
      );
      expect(
        ReminderScheduler.currentDueOccurrence(
          item,
          now: DateTime(2026, 6, 15, 7, 32, 1),
        ),
        isNull,
      );

      final triggeredToday = item.copyWith(lastTriggeredAt: exactTick);
      expect(
        ReminderScheduler.currentDueOccurrence(
          triggeredToday,
          now: DateTime(2026, 6, 15, 7, 30, 15),
        ),
        isNull,
      );
      expect(
        ReminderScheduler.currentDueOccurrence(
          triggeredToday,
          now: DateTime(2026, 6, 16, 7, 30),
        ),
        DateTime(2026, 6, 16, 7, 30),
      );
    });

    test('weekdays and custom rules gate by ISO weekday', () {
      final weekdaysItem = ReminderItem(
        id: 'wd-1',
        title: 'Work check-in',
        scheduledAt: DateTime(2026, 6, 15, 9, 0), // Monday
        recurrence: ReminderRecurrence.weekdays,
        createdAt: DateTime(2026, 6, 1, 9, 0),
      );

      // Friday 2026-06-19
      expect(
        ReminderScheduler.currentDueOccurrence(
          weekdaysItem,
          now: DateTime(2026, 6, 19, 9, 0),
        ),
        DateTime(2026, 6, 19, 9, 0),
      );
      // Saturday 2026-06-20
      expect(
        ReminderScheduler.currentDueOccurrence(
          weekdaysItem,
          now: DateTime(2026, 6, 20, 9, 0),
        ),
        isNull,
      );

      final customItem = ReminderItem(
        id: 'custom-1',
        title: 'Water plants',
        scheduledAt: DateTime(2026, 6, 15, 18, 0),
        recurrence: ReminderRecurrence.custom,
        customWeekdays: const [DateTime.tuesday, DateTime.saturday],
        createdAt: DateTime(2026, 6, 1, 9, 0),
      );

      expect(
        ReminderScheduler.currentDueOccurrence(
          customItem,
          now: DateTime(2026, 6, 15, 18, 0), // Monday
        ),
        isNull,
      );
      expect(
        ReminderScheduler.currentDueOccurrence(
          customItem,
          now: DateTime(2026, 6, 16, 18, 0), // Tuesday
        ),
        DateTime(2026, 6, 16, 18, 0),
      );
    });

    test('snoozedUntil suppresses base occurrence until snooze arrives', () {
      final base = DateTime(2026, 6, 15, 8, 0);
      final snooze = DateTime(2026, 6, 15, 8, 10);
      final item = ReminderItem(
        id: 'snooze-1',
        title: 'Coffee',
        scheduledAt: base,
        recurrence: ReminderRecurrence.daily,
        snoozedUntil: snooze,
        lastTriggeredAt: base,
        createdAt: DateTime(2026, 6, 1, 8, 0),
      );

      // Still inside base catch-up window, but snoozed to 08:10 -> must wait.
      expect(
        ReminderScheduler.currentDueOccurrence(
          item,
          now: DateTime(2026, 6, 15, 8, 1),
        ),
        isNull,
      );
      expect(ReminderScheduler.currentDueOccurrence(item, now: snooze), snooze);

      final afterSnoozeTriggered = item.copyWith(lastTriggeredAt: snooze);
      expect(
        ReminderScheduler.currentDueOccurrence(
          afterSnoozeTriggered,
          now: snooze.add(const Duration(seconds: 5)),
        ),
        isNull,
      );
    });
  });

  group('ReminderScheduler.nextFireAt', () {
    test('handles once future vs elapsed and snoozedUntil priority', () {
      final now = DateTime(2026, 6, 15, 10, 0);
      final futureOnce = ReminderItem(
        id: 'once-fut',
        title: 'Call dentist',
        scheduledAt: DateTime(2026, 6, 15, 11, 0),
        createdAt: now,
      );
      expect(
        ReminderScheduler.nextFireAt(futureOnce, now: now),
        DateTime(2026, 6, 15, 11, 0),
      );
      expect(
        ReminderScheduler.nextFireAt(
          futureOnce,
          now: DateTime(2026, 6, 15, 11, 0),
        ),
        isNull,
      );

      final snoozed = futureOnce.copyWith(
        snoozedUntil: DateTime(2026, 6, 15, 10, 15),
      );
      expect(
        ReminderScheduler.nextFireAt(snoozed, now: now),
        DateTime(2026, 6, 15, 10, 15),
      );

      final disabled = snoozed.copyWith(isEnabled: false);
      expect(ReminderScheduler.nextFireAt(disabled, now: now), isNull);
    });

    test('daily wraps to tomorrow and weekdays skip weekend', () {
      final fridayMorning = DateTime(2026, 6, 19, 9, 30); // Friday
      final daily = ReminderItem(
        id: 'daily-wrap',
        title: 'Hydrate',
        scheduledAt: DateTime(2026, 6, 1, 9, 0),
        recurrence: ReminderRecurrence.daily,
        createdAt: DateTime(2026, 6, 1, 8, 0),
      );
      expect(
        ReminderScheduler.nextFireAt(daily, now: fridayMorning),
        DateTime(2026, 6, 20, 9, 0),
      );

      final weekdays = daily.copyWith(recurrence: ReminderRecurrence.weekdays);
      expect(
        ReminderScheduler.nextFireAt(weekdays, now: fridayMorning),
        DateTime(2026, 6, 22, 9, 0), // Next Monday
      );
    });

    test('mark-done re-anchoring skips already triggered day', () {
      final beforeFire = DateTime(2026, 6, 15, 8, 50);
      final completedEarly = ReminderItem(
        id: 'reanchor',
        title: 'Medication',
        scheduledAt: DateTime(2026, 6, 1, 9, 0),
        recurrence: ReminderRecurrence.daily,
        lastTriggeredAt: DateTime(2026, 6, 15, 9, 0),
        createdAt: DateTime(2026, 6, 1, 8, 0),
      );
      expect(
        ReminderScheduler.nextFireAt(completedEarly, now: beforeFire),
        DateTime(2026, 6, 16, 9, 0),
      );
    });

    test('custom with empty weekdays returns null', () {
      final now = DateTime(2026, 6, 15, 9, 0);
      final emptyCustom = ReminderItem(
        id: 'empty-custom',
        title: 'Never',
        scheduledAt: DateTime(2026, 6, 15, 10, 0),
        recurrence: ReminderRecurrence.custom,
        customWeekdays: const [],
        createdAt: now,
      );
      expect(ReminderScheduler.nextFireAt(emptyCustom, now: now), isNull);
    });

    test('preserves local wall-clock hour/minute across DST dates', () {
      // Uses local DateTime calendar construction across US spring-forward and
      // fall-back dates (2026-03-08 & 2026-11-01) so wall hour/minute never drift.
      final springEve = DateTime(2026, 3, 7, 23, 30);
      final springDaily = ReminderItem(
        id: 'dst-spring',
        title: 'Wake up',
        scheduledAt: DateTime(2026, 3, 1, 7, 30),
        recurrence: ReminderRecurrence.daily,
        createdAt: DateTime(2026, 3, 1, 7, 0),
      );
      final springNext = ReminderScheduler.nextFireAt(
        springDaily,
        now: springEve,
      );
      expect(springNext, DateTime(2026, 3, 8, 7, 30));
      expect(springNext!.hour, 7);
      expect(springNext.minute, 30);

      final fallEve = DateTime(2026, 10, 31, 23, 30);
      final fallNext = ReminderScheduler.nextFireAt(springDaily, now: fallEve);
      expect(fallNext, DateTime(2026, 11, 1, 7, 30));
      expect(fallNext!.hour, 7);
      expect(fallNext.minute, 30);
    });
  });

  group('ReminderScheduler.buildScheduleWindow', () {
    test('caps nearest slots at maxTotalSlots and encodes payload', () {
      final now = DateTime(2026, 6, 15, 8, 0);
      final items = <ReminderItem>[
        for (var i = 1; i <= 70; i++)
          ReminderItem(
            id: 'r-$i',
            title: 'Reminder $i',
            scheduledAt: now.add(Duration(minutes: i)),
            recurrence: ReminderRecurrence.once,
            createdAt: now,
          ),
      ];

      final window = ReminderScheduler.buildScheduleWindow(items, now: now);
      expect(window.length, 48);
      expect(window.first.reminderId, 'r-1');
      expect(window.last.reminderId, 'r-48');

      for (var i = 1; i < window.length; i++) {
        expect(window[i].fireAt.isBefore(window[i - 1].fireAt), isFalse);
      }

      final payload =
          jsonDecode(window.first.payloadJson) as Map<String, dynamic>;
      expect(payload['reminder_id'], 'r-1');
      expect(
        payload['occurrence_epoch_ms'],
        window.first.fireAt.millisecondsSinceEpoch,
      );
      expect(
        window.first.notificationId,
        deterministicNotificationId('r-1', window.first.fireAt),
      );
    });
  });
}
