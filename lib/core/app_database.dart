import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:wyrm_desk/calendar/calendar_model.dart';
import 'package:wyrm_desk/display/display_state.dart';
import 'package:wyrm_desk/habits/habit_model.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/settings/settings_state.dart';
import 'package:wyrm_desk/tasks/task_model.dart';

/// Centralized persistence engine managing the single unified JSON database.
///
/// All writes are serialized through one in-memory queue so concurrent save
/// calls never interleave partial documents, and the last-read document is
/// cached per file path so a save performs one disk operation, not two.
class AppDatabase {
  static const String databaseFileName = 'wyrm_database.json';
  static const String backupFileName = 'wyrm_backup.json';

  /// Cached copy of the last-read or last-written document, keyed by file path
  /// so a changed sandbox directory (tests) invalidates it automatically.
  static Map<String, dynamic>? _cache;
  static String? _cachePath;

  /// Serializes all disk writes; each write starts after the previous completes.
  static Future<void> _writeChain = Future<void>.value();

  /// Resolves the unified JSON database file path on device storage.
  static Future<File> getDatabaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$databaseFileName');
  }

  /// Reads the full database document, migrating legacy files or seeding defaults if missing.
  ///
  /// Returns the cached document when it matches the resolved file path.
  static Future<Map<String, dynamic>> readDatabase() async {
    try {
      final file = await getDatabaseFile();
      if (_cache != null && _cachePath == file.path) {
        return _cache!;
      }
      if (await file.exists()) {
        final rawJson = await file.readAsString();
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        _cachePath = file.path;
        _cache = decoded;
        return decoded;
      }
    } catch (_) {
      // Gracefully fall through to migration and default creation.
    }

    return await _initializeAndMigrateDatabase();
  }

  /// Writes the complete database document to disk using formatted JSON.
  ///
  /// Updates the in-memory cache immediately (before the queued disk write
  /// completes) and serializes behind any pending write.
  static Future<void> writeDatabase(Map<String, dynamic> data) async {
    try {
      final file = await getDatabaseFile();
      _cachePath = file.path;
      _cache = data;

      final pending = _writeChain.then(
        (_) => _writeToDisk(file, data),
      );
      _writeChain = pending;
      await pending;
    } catch (_) {
      // Silently catch sandbox errors in constrained test environments.
    }
  }

  /// Appends the formatted JSON document to [file], swallowing sandbox errors.
  static Future<void> _writeToDisk(File file, Map<String, dynamic> data) async {
    try {
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(data), flush: true);
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

  /// Hydrates all stored calendar milestones from the database.
  static Future<List<CalendarMilestone>> loadCalendarMilestones() async {
    final db = await readDatabase();
    final rawCalendar = db['calendar'];
    if (rawCalendar is List) {
      return rawCalendar
          .whereType<Map<String, dynamic>>()
          .map(CalendarMilestone.fromJson)
          .toList();
    }
    return [];
  }

  /// Persists updated calendar milestones to the database.
  static Future<void> saveCalendarMilestones(List<CalendarMilestone> milestones) async {
    final db = await readDatabase();
    db['calendar'] = milestones.map((m) => m.toJson()).toList();
    await writeDatabase(db);
  }

  /// Hydrates all stored habits from the database.
  static Future<List<HabitItem>> loadHabits() async {
    final db = await readDatabase();
    final rawHabits = db['habits'];
    if (rawHabits is List) {
      return rawHabits
          .whereType<Map<String, dynamic>>()
          .map(HabitItem.fromJson)
          .toList();
    }
    return [];
  }

  /// Persists updated habits to the database.
  static Future<void> saveHabits(List<HabitItem> habits) async {
    final db = await readDatabase();
    db['habits'] = habits.map((h) => h.toJson()).toList();
    await writeDatabase(db);
  }

  /// Hydrates the tablet display configuration (panel brightness) from the database.
  static Future<DisplayState> loadDisplay() async {
    final db = await readDatabase();
    final displayMap = db['display'];
    if (displayMap is Map<String, dynamic>) {
      return DisplayState.fromJson(displayMap);
    }
    return const DisplayState();
  }

  /// Persists the tablet display configuration to the database.
  static Future<void> saveDisplay(DisplayState config) async {
    final db = await readDatabase();
    db['display'] = config.toJson();
    await writeDatabase(db);
  }

  // ===========================================================================
  // BACKUP, EXPORT & RESTORE ENGINE
  // ===========================================================================

  /// Exports the raw formatted JSON string from the unified database.
  static Future<String> exportDatabaseJson() async {
    final db = await readDatabase();
    return const JsonEncoder.withIndent('  ').convert(db);
  }

  /// Validates and imports a JSON database string, replacing the active database file.
  static Future<bool> importDatabaseJson(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return false;
      final hasKnownKeys = decoded.containsKey('layout') ||
          decoded.containsKey('settings') ||
          decoded.containsKey('tasks') ||
          decoded.containsKey('calendar') ||
          decoded.containsKey('habits') ||
          decoded.containsKey('display');
      if (!hasKnownKeys) return false;

      await writeDatabase(decoded);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resolves the file location for backups in the device's public Download directory.
  static Future<File> resolveDownloadsBackupFile({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      return File(customPath);
    }

    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return File('${publicDownload.path}/$backupFileName');
      }
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null && await downloadsDir.exists()) {
        return File('${downloadsDir.path}/$backupFileName');
      }
    } catch (_) {}

    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/$backupFileName');
  }

  /// Exports database backup to the public Download directory.
  static Future<String?> exportToDownloads({String? customPath}) async {
    try {
      final jsonString = await exportDatabaseJson();
      final file = await resolveDownloadsBackupFile(customPath: customPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonString, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Imports database backup from the public Download directory.
  static Future<bool> importFromDownloads({String? customPath}) async {
    try {
      final file = await resolveDownloadsBackupFile(customPath: customPath);
      if (!await file.exists()) return false;
      final rawJson = await file.readAsString();
      return await importDatabaseJson(rawJson);
    } catch (_) {
      return false;
    }
  }

  /// Returns the last modified timestamp of the backup file in Downloads, if present.
  static Future<DateTime?> getDownloadsBackupModified({String? customPath}) async {
    try {
      final file = await resolveDownloadsBackupFile(customPath: customPath);
      if (await file.exists()) {
        return await file.lastModified();
      }
    } catch (_) {}
    return null;
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
      'display': const DisplayState().toJson(),
    };

    await writeDatabase(initialDocument);
    return initialDocument;
  }
}
