import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wyrm_desk/data/backup_file_service.dart';

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

  /// Whether [rawJson] looks like a WYRM database backup.
  ///
  /// A valid backup is a JSON object carrying at least one feature-owned
  /// section key, so an unrelated JSON file is rejected before it can replace
  /// the database.
  static bool isBackupJson(String rawJson) => _decodeBackup(rawJson) != null;

  /// Validates and imports a JSON database string, replacing the active database
  /// file. Returns false for anything that is not a WYRM backup.
  static Future<bool> importDatabaseJson(String rawJson) async {
    final decoded = _decodeBackup(rawJson);
    if (decoded == null) return false;
    try {
      await writeDatabase(decoded);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? _decodeBackup(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      if (!decoded.keys.any(knownSectionKeys.contains)) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // BACKUP FILE TRANSFER - save/open through the platform's own picker
  // ===========================================================================

  /// Forces the document-picker branch on or off; null uses the real platform.
  ///
  /// Exists so the Android path is testable from a desktop test host, where
  /// [Platform.isAndroid] is always false.
  @visibleForTesting
  static bool? debugUseDocumentPicker;

  static bool get _useDocumentPicker =>
      debugUseDocumentPicker ?? Platform.isAndroid;

  /// Saves the whole database as a JSON backup.
  ///
  /// On Android this asks the person where to save it through the system
  /// document picker, so it needs no storage permission. Everywhere else it
  /// writes [backupFileName] into Downloads (falling back to the app documents
  /// directory). [customPath] forces a plain filesystem path.
  ///
  /// Never throws: a failure comes back as [BackupFileResult.failed] with the
  /// platform's reason, because silently returning null is what made the old
  /// Downloads-only implementation impossible to diagnose.
  static Future<BackupFileResult> saveBackup({String? customPath}) async {
    try {
      final json = await exportDatabaseJson();
      if (customPath == null && _useDocumentPicker) {
        final name = await BackupFileService.save(
          fileName: backupFileName,
          contents: json,
        );
        return name == null
            ? const BackupFileResult.cancelled()
            : BackupFileResult.saved(name);
      }
      final file = await _defaultBackupFile(customPath: customPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(json, flush: true);
      return BackupFileResult.saved(file.path);
    } catch (error) {
      return BackupFileResult.failed(_describeError(error));
    }
  }

  /// Picks and reads a backup file without touching the database.
  ///
  /// The caller validates it with [isBackupJson] and imports it with
  /// [importDatabaseJson], so a restore can be confirmed before anything is
  /// replaced. On Android this uses the system document picker (no storage
  /// permission); elsewhere it reads [backupFileName] from Downloads or
  /// [customPath].
  static Future<BackupFileResult> openBackup({String? customPath}) async {
    try {
      if (customPath == null && _useDocumentPicker) {
        final picked = await BackupFileService.open();
        if (picked == null) return const BackupFileResult.cancelled();
        return BackupFileResult.selected(
          name: picked.name,
          contents: picked.contents,
        );
      }
      final file = await _defaultBackupFile(customPath: customPath);
      if (!await file.exists()) {
        return BackupFileResult.failed('No backup file found at ${file.path}');
      }
      return BackupFileResult.selected(
        name: file.uri.pathSegments.last,
        contents: await file.readAsString(),
      );
    } catch (error) {
      return BackupFileResult.failed(_describeError(error));
    }
  }

  /// Resolves a desktop backup location: Downloads when the platform has one,
  /// otherwise the app documents directory.
  static Future<File> _defaultBackupFile({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) return File(customPath);
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return File('${downloads.path}/$backupFileName');
    } catch (_) {
      // Platform has no Downloads concept; fall through to documents.
    }
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$backupFileName');
  }

  static String _describeError(Object error) {
    if (error is BackupFileException) return error.message;
    if (error is FileSystemException) {
      final reason = error.osError?.message;
      return reason == null ? error.message : '${error.message} ($reason)';
    }
    return error.toString();
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

/// How a backup file transfer ended.
enum BackupFileStatus {
  /// The file was written, or read successfully.
  success,

  /// The person dismissed the system file picker; nothing changed.
  cancelled,

  /// The transfer failed; [BackupFileResult.error] explains why.
  failed,
}

/// Outcome of [AppDatabase.saveBackup] or [AppDatabase.openBackup].
@immutable
class BackupFileResult {
  /// What happened.
  final BackupFileStatus status;

  /// Absolute path on desktop, or the picked document's display name on
  /// Android (a document URI is not a filesystem path).
  final String? location;

  /// Raw JSON for a successful open; null when nothing was read.
  final String? contents;

  /// Human-readable reason when [status] is [BackupFileStatus.failed].
  final String? error;

  const BackupFileResult._(
    this.status, {
    this.location,
    this.contents,
    this.error,
  });

  /// A file was written to [location].
  const BackupFileResult.saved(String location)
    : this._(BackupFileStatus.success, location: location);

  /// A file named [name] was read; [contents] is its text.
  const BackupFileResult.selected({
    required String name,
    required String contents,
  }) : this._(BackupFileStatus.success, location: name, contents: contents);

  /// The person dismissed the picker.
  const BackupFileResult.cancelled() : this._(BackupFileStatus.cancelled);

  /// The transfer failed for [error].
  const BackupFileResult.failed(String error)
    : this._(BackupFileStatus.failed, error: error);
}
