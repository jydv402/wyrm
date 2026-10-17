import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/calendar/calendar_state.dart';
import 'package:wyrm_desk/display/display.dart';
import 'package:wyrm_desk/habits/habits.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';
import 'package:wyrm_desk/tasks/tasks_state.dart';

/// Provider managing the background Shelf HTTP and WebSocket server lifecycle.
final webServerProvider = Provider<ShelfWebServer>((ref) {
  final server = ShelfWebServer(
    getLayoutConfig: () => ref.read(cardLayoutProvider),
    getSettingsConfig: () => ref.read(appSettingsProvider),
    getTasksConfig: () => ref.read(tasksProvider),
    getCalendarConfig: () => ref.read(calendarProvider),
    getHabitsConfig: () => ref.read(habitsProvider),
    getDisplayConfig: () => ref.read(displayProvider),
    onSetCardSize: (type, size) {
      ref.read(cardLayoutProvider.notifier).setCardSize(type, size);
    },
    onSet24HourFormat: (is24Hour) {
      ref.read(appSettingsProvider.notifier).set24HourFormat(is24Hour);
    },
    onSetCardFontSize: (fontSize) {
      ref.read(appSettingsProvider.notifier).setCardFontSize(fontSize);
    },
    onSetStartWeekOnMonday: (startMon) {
      ref.read(appSettingsProvider.notifier).setStartWeekOnMonday(startMon);
    },
    onSetBrightness: (brightness) {
      ref.read(displayProvider.notifier).setBrightness(brightness);
    },
    onAddTask: (title, priority) {
      ref.read(tasksProvider.notifier).addTask(title, priority: priority);
    },
    onToggleTask: (id) {
      ref.read(tasksProvider.notifier).toggleTask(id);
    },
    onDeleteTask: (id) {
      ref.read(tasksProvider.notifier).deleteTask(id);
    },
    onAddMilestone: (title, targetDate, {isPinned = false}) {
      ref.read(calendarProvider.notifier).addMilestone(title, targetDate, isPinned: isPinned);
    },
    onDeleteMilestone: (id) {
      ref.read(calendarProvider.notifier).deleteMilestone(id);
    },
    onTogglePinMilestone: (id) {
      ref.read(calendarProvider.notifier).togglePinMilestone(id);
    },
    onAddHabit: (title, type, targetValue, {unit, iconName}) {
      ref.read(habitsProvider.notifier).addHabit(
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
    onScrollToCard: (card) {
      ref.read(cardScrollRequestProvider.notifier).requestScroll(card);
    },
  );

  // Auto-start the server on application startup.
  server.start().catchError((error) {
    // Gracefully handle port conflicts or permission constraints.
    return Future<HttpServer>.error(error);
  });

  // Synchronize layout changes originating on the tablet to connected web clients.
  ref.listen<CardLayoutConfig>(cardLayoutProvider, (previous, next) {
    server.broadcastState(layout: next);
  });

  // Synchronize settings changes originating on the tablet to connected web clients.
  ref.listen<AppSettingsConfig>(appSettingsProvider, (previous, next) {
    server.broadcastState(settings: next);
  });

  // Synchronize task mutations originating on the tablet to connected web clients.
  ref.listen<List<TaskItem>>(tasksProvider, (previous, next) {
    server.broadcastState(tasks: next);
  });

  // Synchronize calendar changes originating on the tablet to connected web clients.
  ref.listen<CalendarState>(calendarProvider, (previous, next) {
    server.broadcastState(calendar: next);
  });

  // Synchronize habits changes originating on the tablet to connected web clients.
  ref.listen<HabitsState>(habitsProvider, (previous, next) {
    server.broadcastState(habits: next);
  });

  // Synchronize display brightness changes to connected web clients.
  ref.listen<DisplayState>(displayProvider, (previous, next) {
    server.broadcastState(display: next);
  });

  ref.onDispose(() {
    server.stop();
  });

  return server;
});
