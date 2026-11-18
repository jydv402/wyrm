import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Centralized persistence engine managing the single unified JSON database.
///
/// All writes are serialized through one in-memory queue so concurrent save
/// calls never interleave partial documents, and the last-read document is
/// cached per file path so a save performs one disk operation, not two.
///
/// The database is feature-agnostic: it stores named JSON sections
/// ([readSection]/[writeSection]) and owns only the transport (disk IO,
/// cache, write queue) and the whole-document backup engine. Every feature
/// owns its section key and the codec between its models and JSON - see the
/// `*_state.dart` files under `lib/features/` and `lib/config/`.
class AppDatabase {
  static const String databaseFileName = 'wyrm_database.json';
  static const String backupFileName = 'wyrm_backup.json';

  /// Document keys the backup importer accepts as evidence of a real
  /// database payload. Each key maps 1:1 to a feature-owned section.
  static const Set<String> knownSectionKeys = {
    'layout',
    'settings',
    'tasks',
    'habits',
    'calendar',
    'display',
  };

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

      final pending = _writeChain.then((_) => _writeToDisk(file, data));
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

  // ===========================================================================
  // GENERIC SECTION ACCESS - features read and write their own JSON here
  // ===========================================================================

  /// Reads the raw JSON value stored under [key], or null when the section
  /// is absent. Features decode this value with their own model codecs.
  static Future<dynamic> readSection(String key) async {
    final db = await readDatabase();
    return db[key];
  }

  /// Replaces the JSON value stored under [key] and persists the document.
  ///
  /// Each feature persists exactly one section under its own key, so
  /// concurrent writers never touch each other's data.
  static Future<void> writeSection(String key, dynamic value) async {
    final db = await readDatabase();
    db[key] = value;
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
      final hasKnownKeys = decoded.keys.any(knownSectionKeys.contains);
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
  static Future<DateTime?> getDownloadsBackupModified({
    String? customPath,
  }) async {
    try {
      final file = await resolveDownloadsBackupFile(customPath: customPath);
      if (await file.exists()) {
        return await file.lastModified();
      }
    } catch (_) {}
    return null;
  }

  /// Seeds default structure and imports existing settings/layout files if present.
  ///
  /// Sections are seeded empty ({}/[]); every feature's loader already falls
  /// back to its own defaults when the stored JSON is blank.
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
      'layout': migratedLayout ?? <String, dynamic>{},
      'settings': migratedSettings ?? <String, dynamic>{},
      'tasks': <dynamic>[],
      'habits': <dynamic>[],
      'calendar': <dynamic>[],
      'display': <String, dynamic>{},
    };

    await writeDatabase(initialDocument);
    return initialDocument;
  }
}
