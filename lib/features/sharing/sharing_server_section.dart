import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/features/sharing/sharing_auth.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_path.dart';
import 'package:wyrm_desk/features/sharing/sharing_service.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Local File Sharing feature's web remote surface: password auth, directory
/// listing, streaming upload/download (with HTTP `Range` support), and CRUD
/// endpoints, plus a metadata-only `sharing` snapshot slice.
class SharingServerSection implements ServerSection {
  /// Canonical snapshot key owned by this section.
  static const String sectionKey = 'sharing';

  /// Authenticator managing the 6-char/custom password and session tokens.
  final SharingAuthService auth;

  /// Filesystem engine performing safe path-guarded I/O.
  final SharingService service;

  /// Reads whether storage permission (`MANAGE_EXTERNAL_STORAGE`) is granted.
  final bool Function() getHasPermission;

  /// Reads the currently scoped sharing root path.
  final String Function() getRootPath;

  /// Reads the current mutation revision counter.
  final int Function() getRevision;

  /// Notifies the tablet state layer after a remote HTTP mutation succeeds.
  final void Function()? onExternalMutation;

  /// Creates a [SharingServerSection].
  SharingServerSection({
    required this.auth,
    required this.service,
    required this.getHasPermission,
    required this.getRootPath,
    required this.getRevision,
    this.onExternalMutation,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.post('/api/sharing/auth', _handleAuth);
    router.get('/api/sharing/files', _handleListFiles);
    router.post('/api/sharing/upload', _handleUpload);
    router.get('/api/sharing/download', _handleDownload);
    router.post('/api/sharing/mkdir', _handleMkdir);
    router.post('/api/sharing/rename', _handleRename);
    router.post('/api/sharing/move', _handleMove);
    router.post('/api/sharing/delete', _handleDelete);
  }

  @override
  bool handleMessage(Map<String, dynamic> message, ServerRuntime runtime) {
    return false;
  }

  @override
  Map<String, dynamic>? snapshot() => <String, dynamic>{
    sectionKey: <String, dynamic>{
      'has_permission': getHasPermission(),
      'root_path': getRootPath(),
      'locked': true,
      'revision': getRevision(),
    },
  };

  Future<Response> _handleAuth(Request request) async {
    try {
      final body = await readJsonBody(request);
      final password = (body['password'] as String? ?? '').trim();
      final token = auth.authenticate(password);
      if (token == null) {
        return jsonError('Invalid sharing password.', statusCode: 401);
      }
      return jsonOk(<String, dynamic>{
        'token': token,
        'has_permission': getHasPermission(),
      });
    } catch (_) {
      return jsonError('Invalid JSON payload.');
    }
  }

  Future<Response> _handleListFiles(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    final query = request.url.queryParameters;
    final path = query['path'] ?? '';
    final sortBy = _parseSortField(query['sort']);
    final ascending = (query['asc'] ?? 'true').toLowerCase() != 'false';

    final result = await service.listDirectory(
      getRootPath(),
      path,
      sortBy: sortBy,
      ascending: ascending,
    );

    switch (result) {
      case SharingSuccess<List<SharedFileEntry>>(:final value):
        var totalBytes = 0;
        for (final entry in value) {
          if (!entry.isDirectory) totalBytes += entry.sizeBytes;
        }
        return jsonResponse(<String, dynamic>{
          'path': SharingPath.normalizeRelativePath(path) ?? '',
          'entries': value.map((e) => e.toJson()).toList(),
          'total_bytes': totalBytes,
        });
      case SharingError<List<SharedFileEntry>>(:final failure):
        return _failureResponse(failure);
    }
  }

  Future<Response> _handleUpload(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    final query = request.url.queryParameters;
    final relativeDir = query['path'] ?? '';
    final rawHeaderName = request.headers['x-file-name'] ?? query['name'] ?? '';
    final decodedName = _decodeHeaderValue(rawHeaderName);
    if (decodedName.isEmpty) {
      return jsonError('Missing X-File-Name header.', statusCode: 400);
    }

    final result = await service.receiveStreamUpload(
      getRootPath(),
      relativeDir,
      decodedName,
      request.read(),
    );

    switch (result) {
      case SharingSuccess<SharedFileEntry>(:final value):
        onExternalMutation?.call();
        return jsonResponse(<String, dynamic>{
          'success': true,
          'entry': value.toJson(),
        }, statusCode: 201);
      case SharingError<SharedFileEntry>(:final failure):
        return _failureResponse(failure);
    }
  }

  Future<Response> _handleDownload(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    final query = request.url.queryParameters;
    final path = query['path'] ?? '';
    final inline = query['inline'] == '1' || query['inline'] == 'true';

    final result = await service.resolveFileForRead(getRootPath(), path);
    switch (result) {
      case SharingError<SharingReadTarget>(:final failure):
        return _failureResponse(failure);
      case SharingSuccess<SharingReadTarget>(:final value):
        return _streamFileResponse(request, value, inline: inline);
    }
  }

  Future<Response> _handleMkdir(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    try {
      final body = await readJsonBody(request);
      final parentPath = body['path'] as String? ?? '';
      final name = body['name'] as String? ?? '';
      final result = await service.createDirectory(
        getRootPath(),
        parentPath,
        name,
      );
      switch (result) {
        case SharingSuccess<SharedFileEntry>(:final value):
          onExternalMutation?.call();
          return jsonOk(<String, dynamic>{'entry': value.toJson()});
        case SharingError<SharedFileEntry>(:final failure):
          return _failureResponse(failure);
      }
    } catch (_) {
      return jsonError('Invalid JSON payload.');
    }
  }

  Future<Response> _handleRename(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    try {
      final body = await readJsonBody(request);
      final path = body['path'] as String? ?? '';
      final newName = body['new_name'] as String? ?? '';
      final result = await service.renameEntry(getRootPath(), path, newName);
      switch (result) {
        case SharingSuccess<SharedFileEntry>(:final value):
          onExternalMutation?.call();
          return jsonOk(<String, dynamic>{'entry': value.toJson()});
        case SharingError<SharedFileEntry>(:final failure):
          return _failureResponse(failure);
      }
    } catch (_) {
      return jsonError('Invalid JSON payload.');
    }
  }

  Future<Response> _handleMove(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    try {
      final body = await readJsonBody(request);
      final path = body['path'] as String? ?? '';
      final targetDir = body['target_dir'] as String? ?? '';
      final result = await service.moveEntry(getRootPath(), path, targetDir);
      switch (result) {
        case SharingSuccess<SharedFileEntry>(:final value):
          onExternalMutation?.call();
          return jsonOk(<String, dynamic>{'entry': value.toJson()});
        case SharingError<SharedFileEntry>(:final failure):
          return _failureResponse(failure);
      }
    } catch (_) {
      return jsonError('Invalid JSON payload.');
    }
  }

  Future<Response> _handleDelete(Request request) async {
    final denied = _guardRequest(request);
    if (denied != null) return denied;

    try {
      final body = await readJsonBody(request);
      final path = body['path'] as String? ?? '';
      final result = await service.deleteEntry(getRootPath(), path);
      switch (result) {
        case SharingSuccess<void>():
          onExternalMutation?.call();
          return jsonOk();
        case SharingError<void>(:final failure):
          return _failureResponse(failure);
      }
    } catch (_) {
      return jsonError('Invalid JSON payload.');
    }
  }

  Response? _guardRequest(Request request) {
    if (!getHasPermission()) {
      return jsonError(
        'All Files Access permission is not granted on the tablet.',
        statusCode: 403,
      );
    }
    final token =
        request.headers['x-sharing-token'] ??
        request.url.queryParameters['token'];
    if (!auth.isValidToken(token)) {
      return jsonError(
        'Authentication required for local file sharing.',
        statusCode: 401,
      );
    }
    return null;
  }

  Response _streamFileResponse(
    Request request,
    SharingReadTarget target, {
    required bool inline,
  }) {
    final total = target.sizeBytes;
    final dispositionType = inline ? 'inline' : 'attachment';
    final safeQuotedName = target.name.replaceAll('"', '_');
    final encodedName = Uri.encodeComponent(target.name);
    final baseHeaders = <String, Object>{
      'Content-Type': target.mimeType,
      'Accept-Ranges': 'bytes',
      'Cache-Control': 'no-store',
      'Content-Disposition':
          "$dispositionType; filename=\"$safeQuotedName\"; filename*=UTF-8''$encodedName",
    };

    final rangeHeader = request.headers['range'];
    if (rangeHeader != null && total > 0) {
      final parsedRange = _parseByteRange(rangeHeader, total);
      if (parsedRange == null) {
        return Response(
          HttpStatus.requestedRangeNotSatisfiable,
          headers: <String, Object>{
            ...baseHeaders,
            'Content-Range': 'bytes */$total',
          },
        );
      }
      final (start, end) = parsedRange;
      final length = end - start + 1;
      return Response(
        HttpStatus.partialContent,
        body: target.file.openRead(start, end + 1),
        headers: <String, Object>{
          ...baseHeaders,
          'Content-Range': 'bytes $start-$end/$total',
          'Content-Length': '$length',
        },
      );
    }

    return Response.ok(
      target.file.openRead(),
      headers: <String, Object>{...baseHeaders, 'Content-Length': '$total'},
    );
  }

  static (int, int)? _parseByteRange(String header, int totalBytes) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null) return null;
    final startStr = match.group(1) ?? '';
    final endStr = match.group(2) ?? '';
    if (startStr.isEmpty && endStr.isEmpty) return null;

    if (startStr.isEmpty) {
      final suffixLength = int.tryParse(endStr);
      if (suffixLength == null || suffixLength <= 0) return null;
      final start = (totalBytes - suffixLength).clamp(0, totalBytes - 1);
      return (start, totalBytes - 1);
    }

    final start = int.tryParse(startStr);
    if (start == null || start < 0 || start >= totalBytes) return null;

    final end = endStr.isEmpty ? totalBytes - 1 : (int.tryParse(endStr) ?? -1);
    if (end < start) return null;
    final clampedEnd = end >= totalBytes ? totalBytes - 1 : end;
    return (start, clampedEnd);
  }

  static SharingSortField _parseSortField(String? raw) {
    return switch (raw) {
      'modified' => SharingSortField.modified,
      'size' => SharingSortField.size,
      _ => SharingSortField.name,
    };
  }

  static String _decodeHeaderValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      return Uri.decodeComponent(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  Response _failureResponse(SharingFailure failure) {
    final statusCode = switch (failure) {
      SharingPermissionDenied() => HttpStatus.forbidden,
      SharingPathTraversal() => HttpStatus.forbidden,
      SharingNotFound() => HttpStatus.notFound,
      SharingAlreadyExists() => HttpStatus.conflict,
      SharingInvalidName() => HttpStatus.badRequest,
      SharingIoError() => HttpStatus.internalServerError,
    };
    return jsonError(failure.message, statusCode: statusCode);
  }
}
