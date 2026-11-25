import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/config/layout_server_section.dart';
import 'package:wyrm_desk/config/settings_server_section.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/data/database_service.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_server_section.dart';
import 'package:wyrm_desk/features/display/display_server_section.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_server_section.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/features/network/network_server_section.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_server_section.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/tasks_server_section.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/services/clock_provider.dart';

/// Provider managing the background Shelf HTTP and WebSocket server lifecycle.
///
/// The transport ([ShelfWebServer]) is feature-agnostic; every feature's
/// routes, WebSocket commands, and snapshot slices live in its
/// [ServerSection], wired here to the matching Riverpod providers.
final webServerProvider = Provider<ShelfWebServer>((ref) {
  final server = ShelfWebServer(
    sections: [
      TasksServerSection(
        getTasks: () => ref.read(tasksProvider),
        onAddTask: (title, priority) {
          ref.read(tasksProvider.notifier).addTask(title, priority: priority);
        },
        onToggleTask: (id) {
          ref.read(tasksProvider.notifier).toggleTask(id);
        },
        onDeleteTask: (id) {
          ref.read(tasksProvider.notifier).deleteTask(id);
        },
      ),
      HabitsServerSection(
        getHabits: () => ref.read(habitsProvider),
        onAddHabit: (title, type, targetValue, {unit, iconName}) {
          ref
              .read(habitsProvider.notifier)
              .addHabit(
                HabitItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  type: type,
                  targetValue: targetValue,
                  unit: unit,
                  iconName: iconName ?? 'bolt',
                  createdAt: DateTime.now(),
                ),
              );
        },
        onToggleHabit: (id, [date]) {
          ref.read(habitsProvider.notifier).toggleCompletion(id, date);
        },
        onStepHabit: (id, delta, [date]) {
          ref.read(habitsProvider.notifier).stepCompletion(id, delta, date);
        },
        onDeleteHabit: (id) {
          ref.read(habitsProvider.notifier).deleteHabit(id);
        },
      ),
      CalendarServerSection(
        getCalendar: () => ref.read(calendarProvider),
        getStartWeekOnMonday: () =>
            ref.read(appSettingsProvider).startWeekOnMonday,
        onAddMilestone: (title, targetDate, {isPinned = false}) {
          ref
              .read(calendarProvider.notifier)
              .addMilestone(title, targetDate, isPinned: isPinned);
        },
        onDeleteMilestone: (id) {
          ref.read(calendarProvider.notifier).deleteMilestone(id);
        },
        onTogglePinMilestone: (id) {
          ref.read(calendarProvider.notifier).togglePinMilestone(id);
        },
        onTravelToDate: (date) {
          ref.read(calendarProvider.notifier).selectDate(date);
        },
      ),
      LayoutServerSection(
        getLayout: () => ref.read(cardLayoutProvider),
        onSetCardSize: (type, size) {
          ref.read(cardLayoutProvider.notifier).setCardSize(type, size);
        },
        onScrollToCard: (card) {
          ref.read(cardScrollRequestProvider.notifier).requestScroll(card);
        },
      ),
      SettingsServerSection(
        getSettings: () => ref.read(appSettingsProvider),
        onSet24HourFormat: (is24Hour) {
          ref.read(appSettingsProvider.notifier).set24HourFormat(is24Hour);
        },
        onSetCardFontSize: (fontSize) {
          ref.read(appSettingsProvider.notifier).setCardFontSize(fontSize);
        },
        onSetStartWeekOnMonday: (startMon) {
          ref.read(appSettingsProvider.notifier).setStartWeekOnMonday(startMon);
        },
      ),
      DisplayServerSection(
        getDisplay: () => ref.read(displayProvider),
        onSetBrightness: (brightness) {
          ref.read(displayProvider.notifier).setBrightness(brightness);
        },
      ),
      NetworkServerSection(
        getNetworkModalOpen: () => ref.read(networkModalOpenProvider),
        onToggleNetworkModal: (open) {
          ref.read(networkModalOpenProvider.notifier).setOpen(open);
        },
      ),
      ReminderServerSection(
        clock: ref.read(clockProvider),
        getReminders: () => ref.read(remindersProvider),
        getActiveAlarm: () => ref.read(activeAlarmProvider),
        onAddReminder:
            ({
              required title,
              required scheduledAt,
              recurrence = ReminderRecurrence.once,
              customWeekdays = const <int>[],
              isEnabled = true,
            }) {
              return ref
                  .read(remindersProvider.notifier)
                  .addReminder(
                    title: title,
                    scheduledAt: scheduledAt,
                    recurrence: recurrence,
                    customWeekdays: customWeekdays,
                    isEnabled: isEnabled,
                  );
            },
        onEditReminder: (reminder) {
          return ref.read(remindersProvider.notifier).editReminder(reminder);
        },
        onToggleReminder: (id, [isEnabled]) {
          return ref
              .read(remindersProvider.notifier)
              .toggleReminder(id, isEnabled);
        },
        onDeleteReminder: (id) {
          return ref.read(remindersProvider.notifier).deleteReminder(id);
        },
        onSnoozeReminder: (id, duration) {
          return ref
              .read(remindersProvider.notifier)
              .snoozeReminder(id, duration: duration);
        },
        onDismissAlarm: () {
          return ref.read(activeAlarmProvider.notifier).dismissActive();
        },
        onSnoozeAlarm: (duration) {
          return ref.read(activeAlarmProvider.notifier).snoozeActive(duration);
        },
      ),
    ],
    onImportDatabase: (jsonString) async {
      return await ref
          .read(databaseServiceProvider)
          .importAndReloadJson(jsonString);
    },
  );

  // Auto-start the server on application startup.
  server.start().catchError((error) {
    // Gracefully handle port conflicts or permission constraints.
    return Future<HttpServer>.error(error);
  });

  // Synchronize layout changes originating on the tablet to connected web clients.
  ref.listen<CardLayoutConfig>(cardLayoutProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize settings changes originating on the tablet to connected web clients.
  ref.listen<AppSettingsConfig>(appSettingsProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize task mutations originating on the tablet to connected web clients.
  ref.listen<List<TaskItem>>(tasksProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize calendar changes originating on the tablet to connected web clients.
  ref.listen<CalendarState>(calendarProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize habits changes originating on the tablet to connected web clients.
  ref.listen<HabitsState>(habitsProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize display brightness changes to connected web clients.
  ref.listen<DisplayState>(displayProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize network connection modal state changes to connected web clients.
  ref.listen<bool>(networkModalOpenProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize reminder list changes to connected web clients.
  ref.listen<RemindersState>(remindersProvider, (previous, next) {
    server.broadcastState();
  });

  // Synchronize active alarm ringing/dismiss/snooze transitions to connected web clients.
  ref.listen<ActiveAlarmState?>(activeAlarmProvider, (previous, next) {
    server.broadcastState();
  });

  ref.onDispose(() {
    server.stop();
  });

  return server;
});
