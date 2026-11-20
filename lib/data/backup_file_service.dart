import 'package:flutter/services.dart';

/// Raised when the platform file picker could not complete a backup transfer.
///
/// Carries the platform's own message, so the Settings page can say why a
/// backup failed instead of a generic "something went wrong".
class BackupFileException implements Exception {
  /// Human-readable reason supplied by the platform side.
  final String message;

  const BackupFileException(this.message);

  @override
  String toString() => message;
}

/// Bridges backup files to the Android document picker (Storage Access
/// Framework).
///
/// Public directories such as `/storage/emulated/0/Download` are not writable
/// by an app on Android 10+ without `MANAGE_EXTERNAL_STORAGE`, and neither the
/// permission nor direct public-directory access is allowed for this use. The
/// picker writes and reads a document the person explicitly chose, which needs
/// no permission at any API level.
///
/// Both methods return `null` when the picker is dismissed, and throw
/// [BackupFileException] when the chosen document cannot be read or written.
class BackupFileService {
  BackupFileService._();

  /// Method channel implemented by the Android host activity (`MainActivity.kt`).
  static const MethodChannel channel = MethodChannel('wyrm_desk/backup');

  /// Asks the host to write [contents] to a document the person chooses.
  ///
  /// Returns the chosen document's display name, or null when cancelled.
  static Future<String?> save({
    required String fileName,
    required String contents,
  }) async {
    try {
      return await channel.invokeMethod<String>('saveBackup', <String, dynamic>{
        'fileName': fileName,
        'contents': contents,
      });
    } on PlatformException catch (error) {
      throw BackupFileException(
        error.message ?? 'The backup could not be saved.',
      );
    }
  }

  /// Asks the host for a document to read.
  ///
  /// Returns the document's display name and text, or null when cancelled.
  static Future<({String name, String contents})?> open() async {
    try {
      final result = await channel.invokeMethod<Object?>('openBackup');
      if (result == null) return null;
      if (result is! Map) {
        throw const BackupFileException('The picker returned no document.');
      }
      final contents = result['contents'];
      if (contents is! String || contents.isEmpty) {
        throw const BackupFileException('The selected file is empty.');
      }
      final name = result['name'];
      return (
        name: name is String && name.isNotEmpty ? name : 'backup.json',
        contents: contents,
      );
    } on PlatformException catch (error) {
      throw BackupFileException(
        error.message ?? 'The backup could not be opened.',
      );
    }
  }
}
