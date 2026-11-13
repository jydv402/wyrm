import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Reads and parses an incoming JSON request body.
Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final body = await request.readAsString();
  return jsonDecode(body) as Map<String, dynamic>;
}

/// Formats a standardized JSON response with no-cache headers.
Response jsonResponse(dynamic data, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  );
}

/// Returns a standardized JSON success response: `{"success": true, ...}`.
Response jsonOk([Map<String, dynamic>? extra]) {
  return jsonResponse({'success': true, ...?extra});
}

/// Returns a standardized JSON error response: `{"error": "message"}`.
Response jsonError(String message, {int statusCode = 400}) {
  return jsonResponse({'error': message}, statusCode: statusCode);
}
