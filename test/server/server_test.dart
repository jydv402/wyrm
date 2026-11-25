import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/repositories/reminder_repository.dart';
import 'package:wyrm_desk/features/calendar/calendar_model.dart';
import 'package:wyrm_desk/features/calendar/calendar_server_section.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/display/display_server_section.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_server_section.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/config/layout_server_section.dart';
import 'package:wyrm_desk/config/settings_server_section.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_server_section.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_server_section.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/tasks_server_section.dart';
import 'package:wyrm_desk/native/alarm_audio_gateway.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/fake_notification_gateway.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';

class _TestClock extends Clock {
  final DateTime _now;

  const _TestClock(this._now);

  @override
  DateTime now() => _now;
}

class _InMemoryReminderRepository implements ReminderRepository {
  List<ReminderItem> items = <ReminderItem>[];

  @override
  Future<List<ReminderItem>> loadReminders() async => items;

  @override
  Future<List<ReminderItem>> activeReminders() async =>
      items.where((item) => item.isEnabled).toList();

  @override
  Future<void> saveReminders(List<ReminderItem> reminders) async {
    items = List<ReminderItem>.unmodifiable(reminders);
  }
}

void main() {
  group('ShelfWebServer REST and WebSocket tests', () {
    late ShelfWebServer server;
    late CardLayoutConfig activeLayout;
    late AppSettingsConfig activeSettings;
    late List<TaskItem> activeTasks;
    late List<CalendarMilestone> activeMilestones;
    late List<HabitItem> activeHabits;
    late List<ReminderItem> activeReminders;
    ActiveAlarmState? activeAlarm;
    late _TestClock reminderClock;
    late int reminderSeq;
    late DisplayState activeDisplay;
    late bool activeNetworkModal;
    DashboardCardType? lastScrolledCard;
    DateTime? activeTravelDate;

    setUp(() async {
      activeTravelDate = null;
      activeLayout = const CardLayoutConfig();
      activeSettings = const AppSettingsConfig();
      activeDisplay = const DisplayState();
      activeNetworkModal = false;
      lastScrolledCard = null;
      reminderClock = _TestClock(DateTime(2026, 9, 20, 8, 0));
      reminderSeq = 1;
      activeAlarm = null;
      activeReminders = [
        ReminderItem(
          id: 'rem_1',
          title: 'Initial Test Reminder',
          scheduledAt: DateTime(2026, 9, 20, 9, 0),
          recurrence: ReminderRecurrence.daily,
          isEnabled: true,
          createdAt: reminderClock.now(),
        ),
      ];
      activeHabits = [
        HabitItem(
          id: 'h_1',
          title: 'Initial Habit',
          type: HabitType.numeric,
          targetValue: 8,
          unit: 'cups',
          completions: {'2026-09-20': 4},
          createdAt: DateTime.now(),
        ),
      ];
      activeTasks = [
        TaskItem(
          id: '1',
          title: 'Initial Test Task',
          isCompleted: false,
          priority: 'high',
          createdAt: DateTime.now(),
        ),
      ];
      activeMilestones = [
        CalendarMilestone(
          id: 'ms_1',
          title: 'Initial Test Milestone',
          targetDate: DateTime(2026, 10, 1),
          isPinned: true,
          createdAt: DateTime.now(),
        ),
      ];

      server = ShelfWebServer(
        sections: [
          TasksServerSection(
            getTasks: () => activeTasks,
            onAddTask: (title, priority) {
              activeTasks = [
                ...activeTasks,
                TaskItem(
                  id: (activeTasks.length + 1).toString(),
                  title: title,
                  priority: priority,
                  createdAt: DateTime.now(),
                ),
              ];
            },
            onToggleTask: (id) {
              activeTasks = activeTasks
                  .map(
                    (t) => t.id == id
                        ? t.copyWith(isCompleted: !t.isCompleted)
                        : t,
                  )
                  .toList();
            },
            onDeleteTask: (id) {
              activeTasks = activeTasks.where((t) => t.id != id).toList();
            },
          ),
          HabitsServerSection(
            getHabits: () => HabitsState(habits: activeHabits),
            onAddHabit: (title, type, targetValue, {unit, iconName}) {
              activeHabits = [
                ...activeHabits,
                HabitItem(
                  id: (activeHabits.length + 1).toString(),
                  title: title,
                  type: type,
                  targetValue: targetValue,
                  unit: unit,
                  iconName: iconName ?? 'bolt',
                  createdAt: DateTime.now(),
                ),
              ];
            },
            onToggleHabit: (id, [date]) {
              final d = date ?? DateTime.now();
              final k = HabitItem.dateKey(d);
              activeHabits = activeHabits.map((h) {
                if (h.id != id) return h;
                final count = h.completionCountOn(d);
                final newCompletions = Map<String, int>.from(h.completions);
                if (count >= h.targetValue) {
                  newCompletions.remove(k);
                } else {
                  newCompletions[k] = h.targetValue;
                }
                return h.copyWith(completions: newCompletions);
              }).toList();
            },
            onStepHabit: (id, delta, [date]) {
              final d = date ?? DateTime.now();
              final k = HabitItem.dateKey(d);
              activeHabits = activeHabits.map((h) {
                if (h.id != id) return h;
                final count = h.completionCountOn(d);
                final newCompletions = Map<String, int>.from(h.completions);
                newCompletions[k] = count + delta;
                return h.copyWith(completions: newCompletions);
              }).toList();
            },
            onDeleteHabit: (id) {
              activeHabits = activeHabits.where((h) => h.id != id).toList();
            },
          ),
          CalendarServerSection(
            getCalendar: () => CalendarState(
              selectedDate: DateTime(2026, 9, 19),
              viewMonth: DateTime(2026, 9, 1),
              milestones: activeMilestones,
            ),
            getStartWeekOnMonday: () => activeSettings.startWeekOnMonday,
            onAddMilestone: (title, date, {isPinned = false}) {
              activeMilestones = [
                ...activeMilestones,
                CalendarMilestone(
                  id: (activeMilestones.length + 1).toString(),
                  title: title,
                  targetDate: date,
                  isPinned: isPinned,
                  createdAt: DateTime.now(),
                ),
              ];
            },
            onDeleteMilestone: (id) {
              activeMilestones = activeMilestones
                  .where((m) => m.id != id)
                  .toList();
            },
            onTogglePinMilestone: (id) {
              activeMilestones = activeMilestones.map((m) {
                if (m.id == id) return m.copyWith(isPinned: !m.isPinned);
                return m;
              }).toList();
            },
            onTravelToDate: (date) => activeTravelDate = date,
          ),
          LayoutServerSection(
            getLayout: () => activeLayout,
            onSetCardSize: (type, size) {
              activeLayout = activeLayout.withSize(type, size);
            },
            onScrollToCard: (card) {
              lastScrolledCard = card;
            },
          ),
          SettingsServerSection(
            getSettings: () => activeSettings,
            onSet24HourFormat: (is24Hour) {
              activeSettings = activeSettings.copyWith(
                is24HourFormat: is24Hour,
              );
            },
            onSetCardFontSize: (fontSize) {
              activeSettings = activeSettings.copyWith(cardFontSize: fontSize);
            },
            onSetStartWeekOnMonday: (startMon) {
              activeSettings = activeSettings.copyWith(
                startWeekOnMonday: startMon,
              );
            },
          ),
          DisplayServerSection(
            getDisplay: () => activeDisplay,
            onSetBrightness: (brightness) {
              activeDisplay = activeDisplay.copyWith(brightness: brightness);
            },
          ),
          NetworkServerSection(
            getNetworkModalOpen: () => activeNetworkModal,
            onToggleNetworkModal: (open) {
              activeNetworkModal = open;
            },
          ),
          ReminderServerSection(
            clock: reminderClock,
            getReminders: () =>
                RemindersState(items: activeReminders, isLoaded: true),
            getActiveAlarm: () => activeAlarm,
            onAddReminder:
                ({
                  required title,
                  required scheduledAt,
                  recurrence = ReminderRecurrence.once,
                  customWeekdays = const <int>[],
                  isEnabled = true,
                }) {
                  reminderSeq += 1;
                  final item = ReminderItem(
                    id: 'rem_$reminderSeq',
                    title: title,
                    scheduledAt: scheduledAt,
                    recurrence: recurrence,
                    customWeekdays: ReminderItem.normalizeWeekdays(
                      customWeekdays,
                    ),
                    isEnabled: isEnabled,
                    createdAt: reminderClock.now(),
                  );
                  activeReminders = [...activeReminders, item];
                  server.broadcastState();
                  return item;
                },
            onEditReminder: (reminder) {
              activeReminders = activeReminders
                  .map((r) => r.id == reminder.id ? reminder : r)
                  .toList();
              server.broadcastState();
            },
            onToggleReminder: (id, [isEnabled]) {
              activeReminders = activeReminders.map((r) {
                if (r.id != id) return r;
                final next = isEnabled ?? !r.isEnabled;
                return r.copyWith(isEnabled: next, clearSnoozedUntil: !next);
              }).toList();
              server.broadcastState();
            },
            onDeleteReminder: (id) {
              activeReminders = activeReminders
                  .where((r) => r.id != id)
                  .toList();
              server.broadcastState();
            },
            onSnoozeReminder: (id, duration) {
              final now = reminderClock.now();
              final target = now.add(duration);
              activeReminders = activeReminders.map((r) {
                if (r.id != id) return r;
                return r.copyWith(
                  isEnabled: true,
                  snoozedUntil: target,
                  lastTriggeredAt: r.lastTriggeredAt ?? now,
                );
              }).toList();
              server.broadcastState();
            },
            onDismissAlarm: () {
              final current = activeAlarm;
              if (current == null) return;
              activeAlarm = null;
              if (!current.isPreview) {
                activeReminders = activeReminders.map((r) {
                  if (r.id != current.reminder.id) return r;
                  return r.copyWith(
                    isEnabled: r.recurrence == ReminderRecurrence.once
                        ? false
                        : r.isEnabled,
                    clearSnoozedUntil: true,
                    lastTriggeredAt: current.firedAt,
                  );
                }).toList();
              }
              server.broadcastState();
            },
            onSnoozeAlarm: (duration) {
              final current = activeAlarm;
              if (current == null) return;
              activeAlarm = null;
              if (!current.isPreview) {
                final now = reminderClock.now();
                activeReminders = activeReminders.map((r) {
                  if (r.id != current.reminder.id) return r;
                  return r.copyWith(
                    isEnabled: true,
                    snoozedUntil: now.add(duration),
                    lastTriggeredAt: r.lastTriggeredAt ?? now,
                  );
                }).toList();
              }
              server.broadcastState();
            },
          ),
        ],
        htmlOverride: '<!DOCTYPE html><html><body>Wyrm Web Test</body></html>',
        cssOverride: 'body { background: #000; }',
        jsOverride: 'console.log("Wyrm JS");',
        faviconOverride: [137, 80, 78, 71, 13, 10, 26, 10],
      );

      // Start on ephemeral port for reliable testing.
      await server.start(port: 0);
    });

    tearDown(() async {
      await server.stop();
    });

    test('GET / serves HTML index client', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.body, contains('Wyrm Web Test'));
    });

    test('GET /style.css serves CSS stylesheet with text/css MIME', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/style.css'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/css'));
      expect(response.body, contains('background: #000'));
    });

    test(
      'GET /app.js serves JavaScript logic with application/javascript MIME',
      () async {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/app.js'),
        );
        expect(response.statusCode, 200);
        expect(
          response.headers['content-type'],
          contains('application/javascript'),
        );
        expect(response.body, contains('Wyrm JS'));
      },
    );

    test('GET /components.js serves components JavaScript logic', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/components.js'),
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        contains('application/javascript'),
      );
      expect(response.body, contains('WyrmUI'));
    });

    test('GET /manifest.webmanifest serves web application manifest', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/manifest.webmanifest'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('manifest+json'));
      expect(response.body, contains('Wyrm Desk Remote'));
    });

    test('GET /vue.global.prod.js serves bundled Vue 3 runtime', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/vue.global.prod.js'),
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        contains('application/javascript'),
      );
      expect(response.body, contains('var Vue=function'));
    });

    test('GET /favicon.ico serves favicon with image/png MIME', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/favicon.ico'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('image/png'));
      expect(response.bodyBytes, equals([137, 80, 78, 71, 13, 10, 26, 10]));
    });

    test(
      'GET /assets/icons/icon_flat.png serves favicon with image/png MIME',
      () async {
        final response = await http.get(
          Uri.parse(
            'http://127.0.0.1:${server.port}/assets/icons/icon_flat.png',
          ),
        );
        expect(response.statusCode, 200);
        expect(response.headers['content-type'], contains('image/png'));
        expect(response.bodyBytes, equals([137, 80, 78, 71, 13, 10, 26, 10]));
      },
    );

    test(
      'GET /api/status returns JSON snapshot of layout, settings, and tasks',
      () async {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/api/status'),
        );
        expect(response.statusCode, 200);

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        expect(data['status'], 'online');
        expect(data['serverUrl'], isNotNull);
        expect(data['ipAddress'], isNotNull);
        expect(data['layout']['clock'], 'small');
        expect(data['settings']['is24HourFormat'], false);
        expect(data['settings']['cardFontSize'], 14.0);
        expect(data['tasks'], isList);
        expect((data['tasks'] as List).length, 1);
      },
    );

    test('GET /api/tasks returns active task list', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks'),
      );
      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as List;
      expect(data.length, 1);
      expect(data.first['title'], 'Initial Test Task');
    });

    test('POST /api/tasks adds a new task item', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': 'New Remote Task', 'priority': 'high'}),
      );

      expect(response.statusCode, 200);
      expect(activeTasks.length, 2);
      expect(activeTasks.last.title, 'New Remote Task');
      expect(activeTasks.last.priority, 'high');
    });

    test('POST /api/tasks/toggle toggles task completion status', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': '1'}),
      );

      expect(response.statusCode, 200);
      expect(activeTasks.first.isCompleted, true);
    });

    test('POST /api/tasks/delete removes a task item', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/tasks/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': '1'}),
      );

      expect(response.statusCode, 200);
      expect(activeTasks.isEmpty, true);
    });

    test('POST /api/layout updates card size accurately', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/layout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card': 'clock', 'size': 'nightstand'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeLayout.clock, CardSize.nightstand);
      expect(lastScrolledCard, DashboardCardType.clock);
    });

    test(
      'POST /api/layout and /api/scroll support reminder and sharing cards',
      () async {
        final reminderResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/layout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'card': 'reminder', 'size': 'medium'}),
        );
        expect(reminderResp.statusCode, 200);
        expect(activeLayout.reminder, CardSize.medium);
        expect(lastScrolledCard, DashboardCardType.reminder);

        final sharingResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/layout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'card': 'sharing', 'size': 'fullscreen'}),
        );
        expect(sharingResp.statusCode, 200);
        expect(activeLayout.sharing, CardSize.fullscreen);
        expect(lastScrolledCard, DashboardCardType.sharing);

        final scrollResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/scroll'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'card': 'reminder'}),
        );
        expect(scrollResp.statusCode, 200);
        expect(jsonDecode(scrollResp.body)['card'], 'reminder');
        expect(lastScrolledCard, DashboardCardType.reminder);
      },
    );

    test('POST /api/scroll triggers onScrollToCard with valid card', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/scroll'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card': 'tasks'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(data['card'], 'tasks');
      expect(lastScrolledCard, DashboardCardType.tasks);
    });

    test('POST /api/scroll returns 400 for invalid card', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/scroll'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'card': 'non_existent_card'}),
      );

      expect(response.statusCode, 400);
    });

    test('POST /api/settings updates 24-hour time format', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'is24HourFormat': true}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeSettings.is24HourFormat, true);
    });

    test('POST /api/settings updates card font size', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cardFontSize': 18.0}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeSettings.cardFontSize, 18.0);
    });

    test('POST /api/settings updates startWeekOnMonday setting', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'startWeekOnMonday': true}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeSettings.startWeekOnMonday, true);
    });

    test('GET /api/status includes display state and habits', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/status'),
      );
      expect(response.statusCode, 200);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['display'], isMap);
      expect(data['display']['brightness'], 1.0);
      expect(data['habits'], isList);
      expect((data['habits'] as List).length, 1);
    });

    test('GET /api/display returns the active display state', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/display'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['brightness'], 1.0);
    });

    test('POST /api/display updates brightness', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/display'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'brightness': 0.4}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeDisplay.brightness, closeTo(0.4, 0.0001));
    });

    test('POST /api/display returns 400 for empty payload', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/display'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      expect(response.statusCode, 400);
    });

    test('GET /api/calendar returns active milestones and metrics', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data.containsKey('yearProgress'), true);
      expect(data.containsKey('quarterProgress'), true);
      expect(data.containsKey('milestones'), true);
      expect(data.containsKey('relativeDistanceText'), true);
      expect(data.containsKey('isSelectedToday'), true);

      final milestones = data['milestones'] as List;
      expect(milestones.isNotEmpty, true);
      expect(milestones.first['title'], 'Initial Test Milestone');
    });

    test('POST /api/calendar/milestones creates a new milestone', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar/milestones'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'New Vacation',
          'target_date': '2026-12-25',
          'is_pinned': false,
        }),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeMilestones.any((m) => m.title == 'New Vacation'), true);
    });

    test(
      'POST /api/calendar/milestones/pin toggles milestone pin state',
      () async {
        final response = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/calendar/milestones/pin',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': 'ms_1'}),
        );

        expect(response.statusCode, 200);
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        expect(data['success'], true);
        expect(
          activeMilestones.firstWhere((m) => m.id == 'ms_1').isPinned,
          false,
        );
      },
    );

    test(
      'POST /api/calendar/milestones/delete removes a milestone item',
      () async {
        final response = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/calendar/milestones/delete',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': 'ms_1'}),
        );

        expect(response.statusCode, 200);
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        expect(data['success'], true);
        expect(activeMilestones.any((m) => m.id == 'ms_1'), false);
      },
    );

    test('POST /api/calendar/travel sets active travel date', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/calendar/travel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'date': '2026-11-25'}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], true);
      expect(activeTravelDate, isNotNull);
      expect(activeTravelDate!.year, 2026);
      expect(activeTravelDate!.month, 11);
      expect(activeTravelDate!.day, 25);
    });

    test(
      'WebSocket connection receives initial snapshot and accepts commands',
      () async {
        final channel = IOWebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:${server.port}/ws'),
        );

        // Await initial snapshot.
        final firstMessage = await channel.stream.first;
        final snapshot =
            jsonDecode(firstMessage.toString()) as Map<String, dynamic>;
        expect(snapshot['type'], 'snapshot');
        expect(snapshot['layout']['clock'], 'small');
        expect(snapshot['layout']['reminder'], 'small');
        expect(snapshot['layout']['sharing'], 'small');
        expect(snapshot['settings']['cardFontSize'], 14.0);
        expect(snapshot['display']['brightness'], 1.0);
        expect(snapshot['tasks'], isList);
        expect(snapshot['calendar'], isMap);

        // Send set_layout message over WebSocket.
        channel.sink.add(
          jsonEncode({
            'type': 'set_layout',
            'card': 'habits',
            'size': 'fullscreen',
          }),
        );

        // Allow event processing.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(activeLayout.habits, CardSize.fullscreen);

        // Send set_settings message over WebSocket.
        channel.sink.add(
          jsonEncode({'type': 'set_settings', 'cardFontSize': 20.0}),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(activeSettings.cardFontSize, 20.0);

        // Send set_display message over WebSocket.
        channel.sink.add(
          jsonEncode({'type': 'set_display', 'brightness': 0.35}),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(activeDisplay.brightness, closeTo(0.35, 0.0001));

        // Send create_task message over WebSocket.
        channel.sink.add(
          jsonEncode({
            'type': 'create_task',
            'title': 'WebSocket Generated Task',
            'priority': 'normal',
          }),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          activeTasks.any((t) => t.title == 'WebSocket Generated Task'),
          true,
        );

        // Send create_milestone message over WebSocket.
        channel.sink.add(
          jsonEncode({
            'type': 'create_milestone',
            'title': 'WS Milestone',
            'targetDate': '2026-11-15',
            'isPinned': true,
          }),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(activeMilestones.any((m) => m.title == 'WS Milestone'), true);

        // Send scroll_to_card message over WebSocket.
        channel.sink.add(
          jsonEncode({'type': 'scroll_to_card', 'card': 'habits'}),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(lastScrolledCard, DashboardCardType.habits);

        // Send travel_to_date message over WebSocket.
        channel.sink.add(
          jsonEncode({'type': 'travel_to_date', 'date': '2027-01-15'}),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(activeTravelDate, isNotNull);
        expect(activeTravelDate!.year, 2027);
        expect(activeTravelDate!.month, 1);
        expect(activeTravelDate!.day, 15);

        await channel.sink.close();
      },
    );

    test('NetworkInfo resolves an IPv4 address', () async {
      final ip = await NetworkInfo.getLocalIpAddress();
      expect(ip, isNotEmpty);
      expect(ip.split('.').length, 4);
    });

    test('GET /api/habits returns active habit list', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
      );
      expect(response.statusCode, 200);

      final List decoded = jsonDecode(response.body);
      expect(decoded.length, 1);
      expect(decoded.first['title'], 'Initial Habit');
      expect(decoded.first['target_value'], 8);
    });

    test('POST /api/habits adds a new habit', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Read 10 Pages',
          'type': 'numeric',
          'target_value': 10,
          'unit': 'pages',
          'icon_name': 'menu_book',
        }),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.length, 2);
      expect(activeHabits.last.title, 'Read 10 Pages');
      expect(activeHabits.last.unit, 'pages');
    });

    test('POST /api/habits supports habit_type and glyph aliases', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Sprint Practice',
          'habit_type': 'binary',
          'glyph': 'run',
        }),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.last.title, 'Sprint Practice');
      expect(activeHabits.last.type, HabitType.binary);
      expect(activeHabits.last.iconName, 'run');
    });

    test('POST /api/habits maps preset emojis to tokens and preserves custom emojis', () async {
      final response1 = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Drink Water Emoji',
          'habit_type': 'numeric',
          'target_value': 8,
          'glyph': '💧',
        }),
      );
      expect(response1.statusCode, 200);
      expect(activeHabits.last.iconName, 'water_drop');

      final response2 = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Eat Fruit',
          'habit_type': 'binary',
          'glyph': '🍎',
        }),
      );
      expect(response2.statusCode, 200);
      expect(activeHabits.last.iconName, '🍎');
    });

    test('WebSocket create_habit creates habit with custom glyph', () async {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );

      await channel.stream.first;

      channel.sink.add(
        jsonEncode({
          'type': 'create_habit',
          'title': 'Evening Journal',
          'habit_type': 'binary',
          'icon_name': 'book',
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(activeHabits.any((h) => h.title == 'Evening Journal'), isTrue);
      expect(
        activeHabits.firstWhere((h) => h.title == 'Evening Journal').iconName,
        'book',
      );

      await channel.sink.close();
    });

    test('POST /api/habits/toggle toggles habit completion', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'h_1', 'date': '2026-09-20'}),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.first.isCompletedOn(DateTime(2026, 9, 20)), isTrue);
    });

    test('POST /api/habits/step increments habit count', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits/step'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'h_1', 'delta': 2, 'date': '2026-09-20'}),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.first.completionCountOn(DateTime(2026, 9, 20)), 6);
    });

    test('POST /api/habits/delete removes a habit', () async {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/habits/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 'h_1'}),
      );
      expect(response.statusCode, 200);
      expect(activeHabits.where((h) => h.id == 'h_1'), isEmpty);
    });

    test(
      'Redesigned assets/web files contain required components and styling',
      () async {
        final htmlFile = File('assets/web/index.html');
        final cssFile = File('assets/web/style.css');
        final jsFile = File('assets/web/app.js');
        final componentsFile = File('assets/web/components.js');
        final manifestFile = File('assets/web/manifest.webmanifest');

        expect(await htmlFile.exists(), isTrue);
        expect(await cssFile.exists(), isTrue);
        expect(await jsFile.exists(), isTrue);
        expect(await componentsFile.exists(), isTrue);
        expect(await manifestFile.exists(), isTrue);

        final html = await htmlFile.readAsString();
        expect(html, contains('id="app"'));
        expect(html, contains('components.js'));
        expect(html, contains('app.js'));
        expect(html, contains('vue.global.prod.js'));

        final components = await componentsFile.readAsString();
        expect(components, contains('WyrmUI'));
        expect(components, contains('WyrmApp'));
        expect(components, contains('ViewDeck'));
        expect(components, contains("id: 'reminder'"));
        expect(components, contains("id: 'sharing'"));
        expect(components, contains("tone: 'plum'"));
        expect(components, contains("tone: 'cobalt'"));
        expect(components, contains('ViewTasks'));
        expect(components, contains('ViewHabits'));
        expect(components, contains('ViewCalendar'));
        expect(components, contains('ViewSettings'));
        expect(components, contains('MilestonesPanel'));
        expect(components, contains('TaskComposer'));
        expect(components, contains('HabitComposer'));
        expect(components, contains('MonthGrid'));
        expect(components, contains('NetworkModalButton'));
        expect(components, contains('NetworkModal'));
        expect(components, contains('TravelModal'));
        expect(components, contains('CalDateCard'));
        expect(components, contains('TravelInsightCard'));
        expect(components, contains('qr:'));

        final css = await cssFile.readAsString();
        expect(css, contains('--t-accent'));
        expect(css, contains("[data-tone='plum']"));
        expect(css, contains("[data-tone='cobalt']"));
        expect(css, contains('.app'));
        expect(css, contains('.nav-rail'));
        expect(css, contains('.modal-backdrop'));
        expect(css, contains('.modal-card'));
        expect(css, contains('.modal-card--travel'));
        expect(css, contains('.btn--gold'));
        expect(css, contains('.cal-date-card'));
        expect(css, contains('.travel-insight'));
        expect(css, contains('.travel-chips-row'));

        final js = await jsFile.readAsString();
        expect(js, contains('WyrmStateStore'));
        expect(js, contains('WyrmWebSocketManager'));
        expect(js, contains('createWyrmActions'));
        expect(js, contains("'reminder'"));
        expect(js, contains("'sharing'"));
        expect(js, contains('window.wyrmRemote'));
        expect(js, contains('travelToDate'));
        expect(js, contains('setAllCardsSize'));
        expect(js, contains('createMilestone'));
        expect(js, contains('deleteMilestone'));
        expect(js, contains('togglePinMilestone'));
        expect(js, contains('createHabit'));
        expect(js, contains('toggleHabit'));
        expect(js, contains('stepHabit'));
        expect(js, contains('deleteHabit'));
        expect(js, contains('scrollToCard'));
        expect(js, contains('setBrightness'));
        expect(js, contains('toggleNetworkModal'));
        expect(js, contains('networkModalOpen'));
        expect(js, contains('exportBackup'));
        expect(js, contains('importBackup'));
        expect(components, contains('database'));
      },
    );

    test('Web remote includes Reminder/Sharing destinations, inline size tiles, and scrollable navigation', () async {
      final css = await File('assets/web/style.css').readAsString();
      final components = await File('assets/web/components.js').readAsString();

      // Destinations and new views
      expect(components, contains("view: 'view-reminder'"));
      expect(components, contains("view: 'view-sharing'"));
      expect(components, contains('ViewReminder'));
      expect(components, contains('ViewSharing'));
      expect(components, contains('ComingSoonPanel'));

      // Inline size control tiles across domain destinations
      expect(components, contains('deck-tile--inline'));
      expect(components, contains("cardMeta('tasks')"));
      expect(components, contains("cardMeta('habits')"));
      expect(components, contains("cardMeta('calendar')"));
      expect(components, contains("cardMeta('reminder')"));
      expect(components, contains("cardMeta('sharing')"));

      // Scrollable navigation (desktop vertical + mobile horizontal + edge fades)
      expect(components, contains('has-fade-start'));
      expect(components, contains('has-fade-end'));
      expect(components, contains('scrollActiveIntoView'));
      expect(css, contains('.deck-tile--inline'));
      expect(css, contains('.nav-items.has-fade-start'));
      expect(css, contains('scroll-snap-type: x proximity'));
      expect(css, contains('overflow-x: auto'));
      expect(css, contains('--item-w:'));
    });

    test(
      'POST /api/calendar/milestones accepts dd/mm/yyyy date format',
      () async {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/calendar/milestones'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': 'Christmas Launch',
            'target_date': '25/12/2026',
            'is_pinned': true,
          }),
        );
        expect(response.statusCode, 200);
        final created = activeMilestones.firstWhere(
          (m) => m.title == 'Christmas Launch',
        );
        expect(created.targetDate.year, 2026);
        expect(created.targetDate.month, 12);
        expect(created.targetDate.day, 25);
        expect(created.isPinned, isTrue);
      },
    );

    test(
      'POST /api/modal/network toggles modal visibility and syncs state',
      () async {
        expect(activeNetworkModal, isFalse);

        // Toggle to open
        var response = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/modal/network'),
          headers: {'Content-Type': 'application/json'},
        );
        expect(response.statusCode, 200);
        var body = jsonDecode(response.body);
        expect(body['success'], isTrue);
        expect(body['open'], isTrue);
        expect(activeNetworkModal, isTrue);

        // Verify status endpoint reflects new state
        final statusResp = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/api/status'),
        );
        expect(statusResp.statusCode, 200);
        final statusBody = jsonDecode(statusResp.body);
        expect(statusBody['networkModalOpen'], isTrue);

        // Explicitly set to false
        response = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/modal/network'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'open': false}),
        );
        expect(response.statusCode, 200);
        body = jsonDecode(response.body);
        expect(body['success'], isTrue);
        expect(body['open'], isFalse);
        expect(activeNetworkModal, isFalse);
      },
    );

    test(
      'WebSocket toggle_network_modal command toggles modal visibility',
      () async {
        expect(activeNetworkModal, isFalse);

        final channel = IOWebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:${server.port}/ws'),
        );
        final initialSnapshot = await channel.stream.first;
        final parsed =
            jsonDecode(initialSnapshot as String) as Map<String, dynamic>;
        expect(parsed['type'], equals('snapshot'));
        expect(parsed['networkModalOpen'], isFalse);

        channel.sink.add(
          jsonEncode({'type': 'toggle_network_modal', 'open': true}),
        );

        // Allow async processing
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(activeNetworkModal, isTrue);

        await channel.sink.close();
      },
    );

    test('GET /api/qr returns valid SVG QR code', () async {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/api/qr'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('image/svg+xml'));
      expect(response.body, startsWith('<svg'));
      expect(response.body, contains('</svg>'));
      expect(response.body, contains('<rect'));

      // Test with custom data
      final customResp = await http.get(
        Uri.parse(
          'http://127.0.0.1:${server.port}/api/qr?data=https://custom.remote.url',
        ),
      );
      expect(customResp.statusCode, 200);
      expect(customResp.headers['content-type'], contains('image/svg+xml'));
      expect(customResp.body, startsWith('<svg'));
    });

    test(
      'GET /api/backup/export downloads full database json attachment',
      () async {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/api/backup/export'),
        );
        expect(response.statusCode, 200);
        expect(response.headers['content-type'], contains('application/json'));
        expect(response.headers['content-disposition'], contains('attachment'));
        expect(
          response.headers['content-disposition'],
          contains('wyrm_backup.json'),
        );
        final json = jsonDecode(response.body);
        expect(json, isA<Map<String, dynamic>>());
      },
    );

    test(
      'POST /api/backup/import accepts valid database json payload',
      () async {
        final payload = jsonEncode({
          'version': 1,
          'layout': {
            'clock': 'medium',
            'habits': 'medium',
            'calendar': 'small',
            'tasks': 'small',
          },
          'settings': {
            'is_24_hour_format': true,
            'card_font_size': 14.0,
            'start_week_on_monday': true,
          },
          'tasks': [],
          'habits': [],
          'calendar': [],
          'display': {'brightness': 0.8},
        });

        final response = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/backup/import'),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        );
        expect(response.statusCode, 200);
        final json = jsonDecode(response.body);
        expect(json['status'], 'ok');
      },
    );

    test(
      'POST /api/backup/import rejects empty and corrupted payloads',
      () async {
        final emptyResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/backup/import'),
          headers: {'Content-Type': 'application/json'},
          body: '  ',
        );
        expect(emptyResp.statusCode, 400);

        final corruptResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/backup/import'),
          headers: {'Content-Type': 'application/json'},
          body: 'not a json map',
        );
        expect(corruptResp.statusCode, 400);
      },
    );

    group('Reminders & Alarms REST and WebSocket endpoints', () {
      test('GET /api/status and GET /api/reminders include reminders and active_alarm', () async {
        final statusResp = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/api/status'),
        );
        expect(statusResp.statusCode, 200);
        final statusJson = jsonDecode(statusResp.body) as Map<String, dynamic>;
        expect(statusJson['reminders'], isList);
        expect((statusJson['reminders'] as List).length, 1);
        expect(statusJson.containsKey('active_alarm'), isTrue);
        expect(statusJson['active_alarm'], isNull);

        // Set an active alarm and verify both /api/reminders and /api/status reflect it.
        final firedAt = DateTime(2026, 9, 20, 9, 0);
        activeAlarm = ActiveAlarmState(
          reminder: activeReminders.first,
          firedAt: firedAt,
        );

        final remResp = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
        );
        expect(remResp.statusCode, 200);
        final remJson = jsonDecode(remResp.body) as Map<String, dynamic>;
        expect((remJson['reminders'] as List).length, 1);
        expect(
          remJson['reminders'][0]['title'],
          equals('Initial Test Reminder'),
        );
        expect(remJson['active_alarm'], isMap);
        expect(remJson['active_alarm']['reminder']['id'], equals('rem_1'));
        expect(
          remJson['active_alarm']['fired_at'],
          equals(firedAt.toIso8601String()),
        );
        expect(remJson['active_alarm']['is_preview'], isFalse);

        final statusWithAlarmResp = await http.get(
          Uri.parse('http://127.0.0.1:${server.port}/api/status'),
        );
        final statusWithAlarm =
            jsonDecode(statusWithAlarmResp.body) as Map<String, dynamic>;
        expect(statusWithAlarm['active_alarm'], isMap);
        expect(
          statusWithAlarm['active_alarm']['reminder']['title'],
          equals('Initial Test Reminder'),
        );
      });

      test('POST /api/reminders creates reminders (snake_case & camelCase) and validates inputs', () async {
        final resp1 = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': '  Stretch break  ',
            'scheduled_at': '2026-09-20T14:30:00.000',
            'recurrence': 'custom',
            'custom_weekdays': [5, 1, 3, 1],
            'is_enabled': true,
          }),
        );
        expect(resp1.statusCode, 200);
        final body1 = jsonDecode(resp1.body) as Map<String, dynamic>;
        expect(body1['success'], isTrue);
        expect(body1['reminder']['title'], equals('Stretch break'));
        expect(body1['reminder']['recurrence'], equals('custom'));
        expect(body1['reminder']['custom_weekdays'], equals([1, 3, 5]));
        expect(body1['reminder']['is_enabled'], isTrue);
        expect((body1['reminders'] as List).length, 2);
        expect(body1.containsKey('active_alarm'), isTrue);

        final resp2 = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': 'Evening meds',
            'scheduledAt': '2026-09-20T21:00:00.000',
            'recurrence': 'weekdays',
            'isEnabled': false,
          }),
        );
        expect(resp2.statusCode, 200);
        final body2 = jsonDecode(resp2.body) as Map<String, dynamic>;
        expect(body2['reminder']['recurrence'], equals('weekdays'));
        expect(body2['reminder']['is_enabled'], isFalse);
        expect(activeReminders.length, 3);

        // Invalid payloads return 400 without mutating state.
        final blankTitleResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': '   ',
            'scheduled_at': '2026-09-20T14:30:00.000',
          }),
        );
        expect(blankTitleResp.statusCode, 400);

        final badDateResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': 'Valid title',
            'scheduled_at': 'not-a-timestamp',
          }),
        );
        expect(badDateResp.statusCode, 400);

        final missingDateResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': 'No date'}),
        );
        expect(missingDateResp.statusCode, 400);

        final emptyCustomDaysResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': 'Custom no days',
            'scheduled_at': '2026-09-20T14:30:00.000',
            'recurrence': 'custom',
            'custom_weekdays': <int>[],
          }),
        );
        expect(emptyCustomDaysResp.statusCode, 400);

        final badJsonResp = await http.post(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
          headers: {'Content-Type': 'application/json'},
          body: '{broken',
        );
        expect(badJsonResp.statusCode, 400);
        expect(activeReminders.length, 3);
      });

      test('PUT /api/reminders/<id> updates fields, toggles is_enabled, snoozes, and handles 404/400', () async {
        // Unknown ID -> 404
        final notFoundResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/missing'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': 'Nope'}),
        );
        expect(notFoundResp.statusCode, 404);

        // Snooze via PUT
        final snoozeResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'snooze_minutes': 25}),
        );
        expect(snoozeResp.statusCode, 200);
        final snoozeBody = jsonDecode(snoozeResp.body) as Map<String, dynamic>;
        expect(
          snoozeBody['reminder']['snoozed_until'],
          equals(DateTime(2026, 9, 20, 8, 25).toIso8601String()),
        );

        // Full field edit clears snoozed_until and updates fields
        final editResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'title': 'Updated Morning Check',
            'scheduled_at': '2026-09-20T10:15:00.000',
            'recurrence': 'custom',
            'custom_weekdays': [2, 4],
            'is_enabled': true,
          }),
        );
        expect(editResp.statusCode, 200);
        final editBody = jsonDecode(editResp.body) as Map<String, dynamic>;
        expect(editBody['reminder']['title'], equals('Updated Morning Check'));
        expect(editBody['reminder']['recurrence'], equals('custom'));
        expect(editBody['reminder']['custom_weekdays'], equals([2, 4]));
        expect(editBody['reminder']['snoozed_until'], isNull);

        // Toggle is_enabled only
        final toggleResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'is_enabled': false}),
        );
        expect(toggleResp.statusCode, 200);
        final toggleBody = jsonDecode(toggleResp.body) as Map<String, dynamic>;
        expect(toggleBody['reminder']['is_enabled'], isFalse);
        expect(activeReminders.first.isEnabled, isFalse);

        // Invalid PUT payloads -> 400
        final emptyUpdateResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{}),
        );
        expect(emptyUpdateResp.statusCode, 400);

        final blankTitleResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': ''}),
        );
        expect(blankTitleResp.statusCode, 400);

        final badSnoozeResp = await http.put(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'snooze_minutes': 'invalid'}),
        );
        expect(badSnoozeResp.statusCode, 400);
      });

      test('DELETE /api/reminders/<id> deletes reminder and returns 404 for unknown id', () async {
        final missingResp = await http.delete(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/unknown'),
        );
        expect(missingResp.statusCode, 404);

        final deleteResp = await http.delete(
          Uri.parse('http://127.0.0.1:${server.port}/api/reminders/rem_1'),
        );
        expect(deleteResp.statusCode, 200);
        final body = jsonDecode(deleteResp.body) as Map<String, dynamic>;
        expect(body['success'], isTrue);
        expect(body['deleted_id'], equals('rem_1'));
        expect(body['reminders'], isEmpty);
        expect(activeReminders, isEmpty);
      });

      test('POST /api/reminders/alarm/dismiss and /snooze control active alarm cleanly', () async {
        // Dismiss while idle succeeds cleanly.
        final idleDismissResp = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/dismiss',
          ),
        );
        expect(idleDismissResp.statusCode, 200);
        final idleBody =
            jsonDecode(idleDismissResp.body) as Map<String, dynamic>;
        expect(idleBody['ok'], isTrue);
        expect(idleBody['active_alarm'], isNull);

        // Trigger an alarm and dismiss it.
        activeAlarm = ActiveAlarmState(
          reminder: activeReminders.first,
          firedAt: DateTime(2026, 9, 20, 9, 0),
        );
        final dismissResp = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/dismiss',
          ),
        );
        expect(dismissResp.statusCode, 200);
        final dismissBody =
            jsonDecode(dismissResp.body) as Map<String, dynamic>;
        expect(dismissBody['ok'], isTrue);
        expect(dismissBody['active_alarm'], isNull);
        expect(activeAlarm, isNull);
        expect(
          activeReminders.first.lastTriggeredAt,
          equals(DateTime(2026, 9, 20, 9, 0)),
        );

        // Trigger again and snooze with default 10m (empty body).
        activeAlarm = ActiveAlarmState(
          reminder: activeReminders.first,
          firedAt: DateTime(2026, 9, 20, 9, 5),
        );
        final defaultSnoozeResp = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/snooze',
          ),
        );
        expect(defaultSnoozeResp.statusCode, 200);
        final defaultSnoozeBody =
            jsonDecode(defaultSnoozeResp.body) as Map<String, dynamic>;
        expect(defaultSnoozeBody['ok'], isTrue);
        expect(defaultSnoozeBody['minutes'], equals(10));
        expect(defaultSnoozeBody['active_alarm'], isNull);
        expect(
          activeReminders.first.snoozedUntil,
          equals(DateTime(2026, 9, 20, 8, 10)),
        );

        // Clamping 1..120 and explicit minutes.
        activeAlarm = ActiveAlarmState(
          reminder: activeReminders.first,
          firedAt: DateTime(2026, 9, 20, 9, 10),
        );
        final clampedLowResp = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/snooze',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'minutes': 0}),
        );
        expect(clampedLowResp.statusCode, 200);
        expect(jsonDecode(clampedLowResp.body)['minutes'], equals(1));
        expect(
          activeReminders.first.snoozedUntil,
          equals(DateTime(2026, 9, 20, 8, 1)),
        );

        activeAlarm = ActiveAlarmState(
          reminder: activeReminders.first,
          firedAt: DateTime(2026, 9, 20, 9, 12),
        );
        final clampedHighResp = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/snooze',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'minutes': 999}),
        );
        expect(clampedHighResp.statusCode, 200);
        expect(jsonDecode(clampedHighResp.body)['minutes'], equals(120));
        expect(
          activeReminders.first.snoozedUntil,
          equals(DateTime(2026, 9, 20, 10, 0)),
        );

        // Malformed snooze payloads -> 400.
        final badJsonSnooze = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/snooze',
          ),
          headers: {'Content-Type': 'application/json'},
          body: '{bad',
        );
        expect(badJsonSnooze.statusCode, 400);

        final nonNumericSnooze = await http.post(
          Uri.parse(
            'http://127.0.0.1:${server.port}/api/reminders/alarm/snooze',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'minutes': 'abc'}),
        );
        expect(nonNumericSnooze.statusCode, 400);
      });

      test(
        'WebSocket reminder_* commands round-trip and broadcast state_update',
        () async {
          final channel = IOWebSocketChannel.connect(
            Uri.parse('ws://127.0.0.1:${server.port}/ws'),
          );
          final incoming = StreamController<Map<String, dynamic>>.broadcast();
          final sub = channel.stream.listen((raw) {
            incoming.add(jsonDecode(raw.toString()) as Map<String, dynamic>);
          });
          addTearDown(() async {
            await sub.cancel();
            await channel.sink.close();
            await incoming.close();
          });

          Future<Map<String, dynamic>> nextMsg() =>
              incoming.stream.first.timeout(const Duration(seconds: 2));

          // 1. Initial snapshot contains reminders and active_alarm: null.
          final snapshot = await nextMsg();
          expect(snapshot['type'], equals('snapshot'));
          expect((snapshot['reminders'] as List).length, 1);
          expect(snapshot.containsKey('active_alarm'), isTrue);
          expect(snapshot['active_alarm'], isNull);

          // 2. reminder_add
          final addFuture = nextMsg();
          channel.sink.add(
            jsonEncode({
              'type': 'reminder_add',
              'title': 'WS Hydration',
              'scheduled_at': '2026-09-20T11:30:00.000',
              'recurrence': 'custom',
              'custom_weekdays': [1, 3, 5],
            }),
          );
          final addUpdate = await addFuture;
          expect(addUpdate['type'], equals('state_update'));
          final added = (addUpdate['reminders'] as List).last;
          expect(added['title'], equals('WS Hydration'));
          expect(added['custom_weekdays'], equals([1, 3, 5]));
          final addedId = added['id'] as String;

          // 3. reminder_edit
          final editFuture = nextMsg();
          channel.sink.add(
            jsonEncode({
              'type': 'reminder_edit',
              'id': addedId,
              'title': 'WS Deep Work',
              'scheduled_at': '2026-09-20T12:00:00.000',
              'recurrence': 'daily',
              'custom_weekdays': <int>[],
              'is_enabled': true,
            }),
          );
          final editUpdate = await editFuture;
          expect(editUpdate['type'], equals('state_update'));
          final edited = (editUpdate['reminders'] as List).firstWhere(
            (r) => r['id'] == addedId,
          );
          expect(edited['title'], equals('WS Deep Work'));
          expect(edited['recurrence'], equals('daily'));

          // 4. reminder_toggle
          final toggleFuture = nextMsg();
          channel.sink.add(
            jsonEncode({
              'type': 'reminder_toggle',
              'id': addedId,
              'is_enabled': false,
            }),
          );
          final toggleUpdate = await toggleFuture;
          final toggled = (toggleUpdate['reminders'] as List).firstWhere(
            (r) => r['id'] == addedId,
          );
          expect(toggled['is_enabled'], isFalse);

          // 5. Tablet triggers active alarm and broadcasts state_update
          final ringFuture = nextMsg();
          activeAlarm = ActiveAlarmState(
            reminder: activeReminders.first,
            firedAt: DateTime(2026, 9, 20, 9, 0),
          );
          server.broadcastState();
          final ringUpdate = await ringFuture;
          expect(ringUpdate['active_alarm'], isMap);
          expect(ringUpdate['active_alarm']['reminder']['id'], equals('rem_1'));

          // 6. reminder_snooze_alarm
          final snoozeFuture = nextMsg();
          channel.sink.add(
            jsonEncode({'type': 'reminder_snooze_alarm', 'minutes': 15}),
          );
          final snoozeUpdate = await snoozeFuture;
          expect(snoozeUpdate['active_alarm'], isNull);
          expect(
            snoozeUpdate['reminders'][0]['snoozed_until'],
            equals(DateTime(2026, 9, 20, 8, 15).toIso8601String()),
          );

          // 7. Ring again and dismiss via reminder_dismiss_alarm
          final ringAgainFuture = nextMsg();
          activeAlarm = ActiveAlarmState(
            reminder: activeReminders.first,
            firedAt: DateTime(2026, 9, 20, 8, 15),
          );
          server.broadcastState();
          await ringAgainFuture;

          final dismissFuture = nextMsg();
          channel.sink.add(jsonEncode({'type': 'reminder_dismiss_alarm'}));
          final dismissUpdate = await dismissFuture;
          expect(dismissUpdate['active_alarm'], isNull);

          // 8. reminder_delete
          final deleteFuture = nextMsg();
          channel.sink.add(
            jsonEncode({'type': 'reminder_delete', 'id': addedId}),
          );
          final deleteUpdate = await deleteFuture;
          expect(
            (deleteUpdate['reminders'] as List).any((r) => r['id'] == addedId),
            isFalse,
          );

          // 9. Malformed WebSocket messages do not crash or mutate state.
          final countBefore = activeReminders.length;
          channel.sink.add(
            jsonEncode({
              'type': 'reminder_add',
              'title': '',
              'scheduled_at': 'bad-date',
            }),
          );
          channel.sink.add(
            jsonEncode({
              'type': 'reminder_edit',
              'id': 'non_existent',
              'title': 'X',
            }),
          );
          channel.sink.add(
            jsonEncode({'type': 'reminder_snooze_alarm', 'minutes': 'bad'}),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(activeReminders.length, countBefore);
        },
      );
    });
  });

  group('ReminderServerSection + Riverpod Notifier integration', () {
    test('bridges RemindersNotifier & ActiveAlarmNotifier with OS sync and WS broadcasts', () async {
      final clock = _TestClock(DateTime(2026, 9, 20, 8, 0));
      final repository = _InMemoryReminderRepository();
      final gateway = FakeNotificationGateway();
      final audio = FakeAlarmAudioGateway();
      final tickController = StreamController<DateTime>.broadcast();

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          clockTimeProvider.overrideWith((ref) => tickController.stream),
          reminderRepositoryProvider.overrideWithValue(repository),
          notificationGatewayProvider.overrideWithValue(gateway),
          alarmAudioGatewayProvider.overrideWithValue(audio),
        ],
      );
      await container.read(remindersProvider.notifier).initialized;

      final server = ShelfWebServer(
        sections: [
          ReminderServerSection(
            clock: container.read(clockProvider),
            getReminders: () => container.read(remindersProvider),
            getActiveAlarm: () => container.read(activeAlarmProvider),
            onAddReminder:
                ({
                  required title,
                  required scheduledAt,
                  recurrence = ReminderRecurrence.once,
                  customWeekdays = const <int>[],
                  isEnabled = true,
                }) {
                  return container
                      .read(remindersProvider.notifier)
                      .addReminder(
                        title: title,
                        scheduledAt: scheduledAt,
                        recurrence: recurrence,
                        customWeekdays: customWeekdays,
                        isEnabled: isEnabled,
                      );
                },
            onEditReminder: (reminder) => container
                .read(remindersProvider.notifier)
                .editReminder(reminder),
            onToggleReminder: (id, [isEnabled]) => container
                .read(remindersProvider.notifier)
                .toggleReminder(id, isEnabled),
            onDeleteReminder: (id) =>
                container.read(remindersProvider.notifier).deleteReminder(id),
            onSnoozeReminder: (id, duration) => container
                .read(remindersProvider.notifier)
                .snoozeReminder(id, duration: duration),
            onDismissAlarm: () =>
                container.read(activeAlarmProvider.notifier).dismissActive(),
            onSnoozeAlarm: (duration) => container
                .read(activeAlarmProvider.notifier)
                .snoozeActive(duration),
          ),
        ],
      );

      final remSub = container.listen<RemindersState>(
        remindersProvider,
        (_, _) => server.broadcastState(),
      );
      final alarmSub = container.listen<ActiveAlarmState?>(
        activeAlarmProvider,
        (_, _) => server.broadcastState(),
      );

      await server.start(port: 0);

      final wsChannel = IOWebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      );
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final wsSub = wsChannel.stream.listen((raw) {
        events.add(jsonDecode(raw.toString()) as Map<String, dynamic>);
      });

      addTearDown(() async {
        remSub.close();
        alarmSub.close();
        await wsSub.cancel();
        await wsChannel.sink.close();
        await events.close();
        await server.stop();
        container.dispose();
        await gateway.dispose();
        await tickController.close();
      });

      final initial = await events.stream.first;
      expect(initial['type'], equals('snapshot'));
      expect(initial['reminders'], isEmpty);
      expect(initial['active_alarm'], isNull);

      // Create reminder over HTTP -> updates RemindersNotifier, schedules OS alarm, broadcasts WS.
      final broadcastFuture = events.stream.first;
      final createResp = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/api/reminders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Standup Call',
          'scheduled_at': '2026-09-20T09:00:00.000',
          'recurrence': 'once',
        }),
      );
      expect(createResp.statusCode, 200);
      final createUpdate = await broadcastFuture;
      expect((createUpdate['reminders'] as List).length, 1);
      expect(gateway.scheduled.length, 1);

      final created = container.read(remindersProvider).items.single;
      expect(created.title, equals('Standup Call'));

      // Trigger alarm on tablet side -> audio plays & WS receives active_alarm.
      final ringBroadcast = events.stream.first;
      await container
          .read(activeAlarmProvider.notifier)
          .triggerAlarm(created, DateTime(2026, 9, 20, 9, 0));
      final ringUpdate = await ringBroadcast;
      expect(audio.isPlaying, isTrue);
      expect(ringUpdate['active_alarm']['reminder']['id'], created.id);

      // Dismiss via WS -> stops chime, clears activeAlarm, disables once reminder, broadcasts null.
      final dismissBroadcast = events.stream.firstWhere(
        (msg) =>
            msg['active_alarm'] == null &&
            (msg['reminders'] as List).first['is_enabled'] == false,
      );
      wsChannel.sink.add(jsonEncode({'type': 'reminder_dismiss_alarm'}));
      final dismissedUpdate = await dismissBroadcast.timeout(
        const Duration(seconds: 2),
      );
      expect(dismissedUpdate['active_alarm'], isNull);
      expect(audio.isPlaying, isFalse);
      expect(container.read(activeAlarmProvider), isNull);
      expect(container.read(remindersProvider).items.single.isEnabled, isFalse);
    });
  });
}
