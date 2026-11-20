import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wyrm_desk/data/backup_file_service.dart';

/// Persistence engine for the single unified JSON database.
///
/// Writes are serialized through one queue, and the last-read document is
/// cached per resolved path. The engine is feature-agnostic: features own their
/// section key and codec through [readSection]/[writeSection], while this class
/// owns disk IO, the cache, and whole-document backup/restore.
class AppDatabase {
  static const String databaseFileName = 'wyrm_database.json';
  static const String backupFileName = 'wyrm_backup.json';

  /// Section keys that mark a JSON object as a real database payload. Each key
  /// maps 1:1 to a feature-owned section.
  static const Set<String> knownSectionKeys = {
    'layout',
    'settings',
    'tasks',
    'habits',
    'calendar',
    'display',
  };

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Cached copy of the last-read or last-written document, keyed by file path
  /// so a changed sandbox directory (tests) invalidates it automatically.
  static Map<String, dynamic>? _cache;
  static String? _cachePath;

  /// Serializes writes; each one starts after the previous completes.
  static Future<void> _writeChain = Future<void>.value();

  static Future<File> _databaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$databaseFileName');
  }

  /// Reads the whole document, migrating legacy files or seeding defaults when
  /// no readable store exists.
  static Future<Map<String, dynamic>> readDatabase() async {
    try {
      final file = await _databaseFile();
      if (_cache != null && _cachePath == file.path) return _cache!;
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          _cachePath = file.path;
          _cache = decoded;
          return decoded;
        }
      }
    } catch (_) {
      // No usable store (missing plugin, unreadable file): seed below.
    }
    return _initializeAndMigrateDatabase();
  }

  /// Caches [data] immediately and persists it behind any pending write.
  ///
  /// Disk failures are swallowed so a constrained sandbox cannot take down a
  /// feature's in-memory state, and never poison the write queue.
  static Future<void> writeDatabase(Map<String, dynamic> data) async {
    try {
      final file = await _databaseFile();
      _cachePath = file.path;
      _cache = data;
      _writeChain = _writeChain.then((_) async {
        try {
          await file.writeAsString(_encoder.convert(data), flush: true);
        } catch (_) {
          // Keep the queue flowing; the cache already reflects the write.
        }
      });
      await _writeChain;
    } catch (_) {
      // Sandboxed hosts may not expose a documents directory.
    }
  }

  // ===========================================================================
  // GENERIC SECTION ACCESS - features read and write their own JSON here
  // ===========================================================================

  /// The raw JSON value stored under [key], or null when absent.
  static Future<dynamic> readSection(String key) async =>
      (await readDatabase())[key];

  /// Replaces the JSON value stored under [key] and persists the document.
  static Future<void> writeSection(String key, dynamic value) async {
    final db = await readDatabase();
    db[key] = value;
    await writeDatabase(db);
  }

  // ===========================================================================
  // BACKUP, EXPORT & RESTORE ENGINE
  // ===========================================================================

  /// The whole document as formatted JSON.
  static Future<String> exportDatabaseJson() async =>
      _encoder.convert(await readDatabase());

  /// Whether [rawJson] is a JSON object carrying at least one known section
  /// key, so an unrelated JSON file is rejected before it can replace the DB.
  static bool isBackupJson(String rawJson) => _decodeBackup(rawJson) != null;

  /// Replaces the database with a validated backup; false for anything else.
  static Future<bool> importDatabaseJson(String rawJson) async {
    final decoded = _decodeBackup(rawJson);
    if (decoded == null) return false;
    // writeDatabase never throws, so a validated payload always imports.
    await writeDatabase(decoded);
    return true;
  }

  static Map<String, dynamic>? _decodeBackup(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic> &&
          decoded.keys.any(knownSectionKeys.contains)) {
        return decoded;
      }
    } catch (_) {
      // Not JSON: not a backup.
    }
    return null;
  }

  // ===========================================================================
  // BACKUP FILE TRANSFER - save/open through the platform's own picker
  // ===========================================================================

  /// Forces the document-picker branch on or off; null uses the real platform.
  /// Lets the Android path run on a desktop test host.
  @visibleForTesting
  static bool? debugUseDocumentPicker;

  static bool get _useDocumentPicker =>
      debugUseDocumentPicker ?? Platform.isAndroid;

  /// Saves the whole database as a JSON backup.
  ///
  /// Android asks the person where to save it through the system document
  /// picker (no storage permission). Elsewhere it writes [backupFileName] to
  /// Downloads, falling back to the app documents directory. [customPath]
  /// forces a plain filesystem path.
  ///
  /// Never throws: a failure returns [BackupFileResult.failed] with the reason.
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
  /// [importDatabaseJson], so a restore is confirmed before anything changes.
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

  /// Downloads when the platform has one, otherwise the app documents folder.
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

  /// Seeds a document, migrating the pre-unification layout/settings files.
  ///
  /// Sections are seeded empty ({}/[]); every feature's loader already falls
  /// back to its own defaults when the stored JSON is blank.
  static Future<Map<String, dynamic>> _initializeAndMigrateDatabase() async {
    final document = <String, dynamic>{
      'version': 1,
      'layout': await _readLegacy('card_layout.json') ?? <String, dynamic>{},
      'settings': await _readLegacy('app_settings.json') ?? <String, dynamic>{},
      'tasks': <dynamic>[],
      'habits': <dynamic>[],
      'calendar': <dynamic>[],
      'display': <String, dynamic>{},
    };
    await writeDatabase(document);
    return document;
  }

  /// Reads one legacy JSON file from the documents directory, or null.
  static Future<Map<String, dynamic>?> _readLegacy(String name) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$name');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
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

  /// Absolute path on desktop, or the document's display name on Android
  /// (a document URI is not a filesystem path).
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
