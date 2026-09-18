import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';

/// Centralized persistence engine managing the single unified JSON database.
class AppDatabase {
  static const String databaseFileName = 'wyrm_database.json';

  /// Resolves the unified JSON database file path on device storage.
  static Future<File> getDatabaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$databaseFileName');
  }

  /// Reads the full database document, migrating legacy files or seeding defaults if missing.
  static Future<Map<String, dynamic>> readDatabase() async {
    try {
      final file = await getDatabaseFile();
      if (await file.exists()) {
        final rawJson = await file.readAsString();
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        return decoded;
      }
    } catch (_) {
      // Gracefully fall through to migration and default creation.
    }

    return await _initializeAndMigrateDatabase();
  }

  /// Writes the complete database document to disk using formatted JSON.
  static Future<void> writeDatabase(Map<String, dynamic> data) async {
    try {
      final file = await getDatabaseFile();
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(data));
    } catch (_) {
      // Silently catch write errors in constrained test or sandbox environments.
    }
  }

  /// Hydrates card layout configuration from the database.
  static Future<CardLayoutConfig> loadLayout() async {
    final db = await readDatabase();
    final layoutMap = db['layout'];
    if (layoutMap is Map<String, dynamic>) {
      return CardLayoutConfig.fromJson(layoutMap);
    }
    return const CardLayoutConfig();
  }

  /// Persists updated card layout configuration to the database.
  static Future<void> saveLayout(CardLayoutConfig config) async {
    final db = await readDatabase();
    db['layout'] = config.toJson();
    await writeDatabase(db);
  }

  /// Hydrates application settings configuration from the database.
  static Future<AppSettingsConfig> loadSettings() async {
    final db = await readDatabase();
    final settingsMap = db['settings'];
    if (settingsMap is Map<String, dynamic>) {
      return AppSettingsConfig.fromJson(settingsMap);
    }
    return const AppSettingsConfig();
  }

  /// Persists updated application settings configuration to the database.
  static Future<void> saveSettings(AppSettingsConfig config) async {
    final db = await readDatabase();
    db['settings'] = config.toJson();
    await writeDatabase(db);
  }

  /// Hydrates all stored task items from the database.
  static Future<List<TaskItem>> loadTasks() async {
    final db = await readDatabase();
    final rawTasks = db['tasks'];
    if (rawTasks is List) {
      return rawTasks
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList();
    }
    return [];
  }

  /// Persists updated task items to the database.
  static Future<void> saveTasks(List<TaskItem> tasks) async {
    final db = await readDatabase();
    db['tasks'] = tasks.map((t) => t.toJson()).toList();
    await writeDatabase(db);
  }

  /// Seeds default structure and imports existing settings/layout files if present.
  static Future<Map<String, dynamic>> _initializeAndMigrateDatabase() async {
    Map<String, dynamic>? migratedLayout;
    Map<String, dynamic>? migratedSettings;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final layoutFile = File('${directory.path}/card_layout.json');
      if (await layoutFile.exists()) {
        final content = await layoutFile.readAsString();
        migratedLayout = jsonDecode(content) as Map<String, dynamic>;
      }

      final settingsFile = File('${directory.path}/app_settings.json');
      if (await settingsFile.exists()) {
        final content = await settingsFile.readAsString();
        migratedSettings = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}

    final initialDocument = <String, dynamic>{
      'version': 1,
      'layout': migratedLayout ?? const CardLayoutConfig().toJson(),
      'settings': migratedSettings ?? const AppSettingsConfig().toJson(),
      'tasks': <dynamic>[],
      'habits': <dynamic>[],
      'calendar': <dynamic>[],
    };

    await writeDatabase(initialDocument);
    return initialDocument;
  }
}
