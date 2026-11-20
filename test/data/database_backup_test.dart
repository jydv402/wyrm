import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/data/backup_file_service.dart';
import 'package:wyrm_desk/data/database_service.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/tasks/task_model.dart';
import 'package:wyrm_desk/features/tasks/tasks_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/display/display_state.dart';

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
    AppDatabase.debugUseDocumentPicker = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFileService.channel, null);
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

    test(
      'importDatabaseJson validates payload structure and rejects invalid JSON',
      () async {
        // Rejects plain string
        final invalidStr = await AppDatabase.importDatabaseJson(
          'invalid json string',
        );
        expect(invalidStr, false);

        // Rejects empty map without known database keys
        final emptyMap = await AppDatabase.importDatabaseJson('{"foo": "bar"}');
        expect(emptyMap, false);

        expect(AppDatabase.isBackupJson('{"foo": "bar"}'), isFalse);
        expect(AppDatabase.isBackupJson('[]'), isFalse);

        // Accepts valid database payload
        final validPayload = jsonEncode({
          'version': 1,
          'layout': const CardLayoutConfig().toJson(),
          'settings': const AppSettingsConfig(
            is24HourFormat: true,
            cardFontSize: 16.0,
          ).toJson(),
          'tasks': [
            {
              'id': 'task-1',
              'title': 'Test Backup Task',
              'is_completed': false,
              'priority': 'high',
            },
          ],
          'habits': [],
          'calendar': [],
          'display': const DisplayState(brightness: 0.75).toJson(),
        });

        expect(AppDatabase.isBackupJson(validPayload), isTrue);

        final success = await AppDatabase.importDatabaseJson(validPayload);
        expect(success, true);

        // Verify persisted state reflects imported changes
        final loadedSettings =
            await AppDatabase.readSection('settings') as Map<String, dynamic>;
        expect(loadedSettings['is_24_hour_format'], true);
        expect(loadedSettings['card_font_size'], 16.0);

        final loadedTasks = await AppDatabase.readSection('tasks') as List;
        expect(loadedTasks.length, 1);
        expect(loadedTasks.first['title'], 'Test Backup Task');
      },
    );

    test(
      'saveBackup and openBackup round-trip through an explicit path',
      () async {
        final testBackupFile = '${tempDir.path}/wyrm_custom_backup.json';

        // Seed database with unique task
        final initialTasks = [
          TaskItem(
            id: 'test-seed-1',
            title: 'Export Verification Task',
            createdAt: DateTime.now(),
          ),
        ];
        await AppDatabase.writeSection(
          'tasks',
          initialTasks.map((t) => t.toJson()).toList(),
        );

        final saved = await AppDatabase.saveBackup(customPath: testBackupFile);
        expect(saved.status, BackupFileStatus.success);
        expect(saved.location, testBackupFile);
        expect(await File(testBackupFile).exists(), true);

        // Mutate database with different task
        await AppDatabase.writeSection('tasks', [
          TaskItem(
            id: 'different-task',
            title: 'Overwritten Task',
            createdAt: DateTime.now(),
          ).toJson(),
        ]);
        final intermediateTasks =
            await AppDatabase.readSection('tasks') as List;
        expect(intermediateTasks.first['title'], 'Overwritten Task');

        final picked = await AppDatabase.openBackup(customPath: testBackupFile);
        expect(picked.status, BackupFileStatus.success);
        expect(picked.location, 'wyrm_custom_backup.json');
        expect(picked.contents, isNotNull);
        expect(AppDatabase.isBackupJson(picked.contents!), isTrue);

        expect(await AppDatabase.importDatabaseJson(picked.contents!), true);

        // Verify restored task
        final restoredTasks = await AppDatabase.readSection('tasks') as List;
        expect(restoredTasks.length, 1);
        expect(restoredTasks.first['title'], 'Export Verification Task');
      },
    );

    test(
      'openBackup explains a missing file instead of failing silently',
      () async {
        final missing = '${tempDir.path}/not_there.json';

        final result = await AppDatabase.openBackup(customPath: missing);

        expect(result.status, BackupFileStatus.failed);
        expect(result.error, contains(missing));
      },
    );

    test(
      'saveBackup reports the filesystem reason it could not write',
      () async {
        // A directory can never be opened for writing: a real, deterministic
        // failure that must surface as a message rather than a null return.
        final result = await AppDatabase.saveBackup(customPath: tempDir.path);

        expect(result.status, BackupFileStatus.failed);
        expect(result.error, isNotEmpty);
      },
    );

    group('document picker (Android SAF)', () {
      late List<MethodCall> calls;
      late Object? Function(MethodCall call) handler;

      setUp(() {
        AppDatabase.debugUseDocumentPicker = true;
        calls = <MethodCall>[];
        handler = (_) => null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(BackupFileService.channel, (
              MethodCall call,
            ) async {
              calls.add(call);
              return handler(call);
            });
      });

      test(
        'saveBackup hands the JSON to the picker and reports its name',
        () async {
          handler = (_) => 'wyrm_backup.json';

          final result = await AppDatabase.saveBackup();

          expect(result.status, BackupFileStatus.success);
          expect(result.location, 'wyrm_backup.json');
          expect(calls.single.method, 'saveBackup');
          final args = calls.single.arguments as Map<dynamic, dynamic>;
          expect(args['fileName'], AppDatabase.backupFileName);
          expect(args['contents'], contains('"version"'));
        },
      );

      test('saveBackup treats a dismissed picker as cancelled', () async {
        final result = await AppDatabase.saveBackup();

        expect(result.status, BackupFileStatus.cancelled);
        expect(result.error, isNull);
      });

      test('openBackup returns the picked document contents', () async {
        handler = (_) => {
          'name': 'my_backup.json',
          'contents': '{"tasks": []}',
        };

        final result = await AppDatabase.openBackup();

        expect(result.status, BackupFileStatus.success);
        expect(result.location, 'my_backup.json');
        expect(result.contents, '{"tasks": []}');
        expect(calls.single.method, 'openBackup');
      });

      test('openBackup treats a dismissed picker as cancelled', () async {
        final result = await AppDatabase.openBackup();

        expect(result.status, BackupFileStatus.cancelled);
        expect(result.contents, isNull);
      });

      test('platform failures carry their message to the caller', () async {
        handler = (_) => throw PlatformException(
          code: 'SAVE_FAILED',
          message: 'The selected file could not be opened for writing',
        );

        final result = await AppDatabase.saveBackup();

        expect(result.status, BackupFileStatus.failed);
        expect(
          result.error,
          'The selected file could not be opened for writing',
        );
      });
    });
  });

  group('DatabaseService State Reload Tests', () {
    test(
      'reloadAllState updates all active Riverpod notifiers from disk',
      () async {
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
        final updatedSettings = const AppSettingsConfig(
          is24HourFormat: true,
          cardFontSize: 19.0,
        );
        await AppDatabase.writeSection('settings', updatedSettings.toJson());

        final updatedTasks = [
          TaskItem(
            id: 'reloaded-1',
            title: 'Reloaded Task',
            createdAt: DateTime.now(),
          ),
        ];
        await AppDatabase.writeSection(
          'tasks',
          updatedTasks.map((t) => t.toJson()).toList(),
        );

        // Invoke DatabaseService.reloadAllState()
        final dbService = container.read(databaseServiceProvider);
        await dbService.reloadAllState();

        // Verify in-memory state updated
        expect(container.read(appSettingsProvider).is24HourFormat, true);
        expect(container.read(appSettingsProvider).cardFontSize, 19.0);
        expect(
          container.read(tasksProvider).any((t) => t.id == 'reloaded-1'),
          true,
        );
      },
    );
  });
}
