import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';
import 'package:wyrm_desk/tasks/tasks_state.dart';
import 'package:wyrm_desk/calendar/calendar_state.dart';
import 'package:wyrm_desk/habits/habits_state.dart';
import 'package:wyrm_desk/display/display_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wyrm_db_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('AppDatabase Backup & Restore Unit Tests', () {
    test('exportDatabaseJson produces valid formatted JSON document', () async {
      final jsonString = await AppDatabase.exportDatabaseJson();
      expect(jsonString, isNotEmpty);
      final decoded = jsonDecode(jsonString);
      expect(decoded, isA<Map<String, dynamic>>());
      final map = decoded as Map<String, dynamic>;
      expect(map.containsKey('layout'), true);
      expect(map.containsKey('settings'), true);
    });

    test('importDatabaseJson validates payload structure and rejects invalid JSON', () async {
      // Rejects plain string
      final invalidStr = await AppDatabase.importDatabaseJson('invalid json string');
      expect(invalidStr, false);

      // Rejects empty map without known database keys
      final emptyMap = await AppDatabase.importDatabaseJson('{"foo": "bar"}');
      expect(emptyMap, false);

      // Accepts valid database payload
      final validPayload = jsonEncode({
        'version': 1,
        'layout': const CardLayoutConfig().toJson(),
        'settings': const AppSettingsConfig(is24HourFormat: true, cardFontSize: 16.0).toJson(),
        'tasks': [
          {'id': 'task-1', 'title': 'Test Backup Task', 'is_completed': false, 'priority': 'high'}
        ],
        'habits': [],
        'calendar': [],
        'display': const DisplayState(brightness: 0.75).toJson(),
      });

      final success = await AppDatabase.importDatabaseJson(validPayload);
      expect(success, true);

      // Verify persisted state reflects imported changes
      final loadedSettings = await AppDatabase.loadSettings();
      expect(loadedSettings.is24HourFormat, true);
      expect(loadedSettings.cardFontSize, 16.0);

      final loadedTasks = await AppDatabase.loadTasks();
      expect(loadedTasks.length, 1);
      expect(loadedTasks.first.title, 'Test Backup Task');
    });

    test('exportToDownloads and importFromDownloads work with custom path', () async {
      final testBackupFile = '${tempDir.path}/wyrm_custom_backup.json';

      // Seed database with unique task
      final initialTasks = [
        TaskItem(
          id: 'test-seed-1',
          title: 'Export Verification Task',
          createdAt: DateTime.now(),
        ),
      ];
      await AppDatabase.saveTasks(initialTasks);

      // Export
      final exportedPath = await AppDatabase.exportToDownloads(customPath: testBackupFile);
      expect(exportedPath, testBackupFile);
      expect(await File(testBackupFile).exists(), true);

      // Check modified timestamp
      final modified = await AppDatabase.getDownloadsBackupModified(customPath: testBackupFile);
      expect(modified, isNotNull);

      // Mutate database with different task
      await AppDatabase.saveTasks([
        TaskItem(
          id: 'different-task',
          title: 'Overwritten Task',
          createdAt: DateTime.now(),
        ),
      ]);
      final intermediateTasks = await AppDatabase.loadTasks();
      expect(intermediateTasks.first.title, 'Overwritten Task');

      // Import backup from custom path
      final importSuccess = await AppDatabase.importFromDownloads(customPath: testBackupFile);
      expect(importSuccess, true);

      // Verify restored task
      final restoredTasks = await AppDatabase.loadTasks();
      expect(restoredTasks.length, 1);
      expect(restoredTasks.first.title, 'Export Verification Task');
    });
  });

  group('DatabaseService State Reload Tests', () {
    test('reloadAllState updates all active Riverpod notifiers from disk', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize all providers
      container.read(cardLayoutProvider);
      container.read(appSettingsProvider);
      container.read(tasksProvider);
      container.read(calendarProvider);
      container.read(habitsProvider);
      container.read(displayProvider);

      // Write direct changes to database on disk
      final updatedSettings = const AppSettingsConfig(is24HourFormat: true, cardFontSize: 19.0);
      await AppDatabase.saveSettings(updatedSettings);

      final updatedTasks = [
        TaskItem(
          id: 'reloaded-1',
          title: 'Reloaded Task',
          createdAt: DateTime.now(),
        ),
      ];
      await AppDatabase.saveTasks(updatedTasks);

      // Invoke DatabaseService.reloadAllState()
      final dbService = container.read(databaseServiceProvider);
      await dbService.reloadAllState();

      // Verify in-memory state updated
      expect(container.read(appSettingsProvider).is24HourFormat, true);
      expect(container.read(appSettingsProvider).cardFontSize, 19.0);
      expect(container.read(tasksProvider).any((t) => t.id == 'reloaded-1'), true);
    });
  });
}
