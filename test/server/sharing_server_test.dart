import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wyrm_desk/features/sharing/sharing_auth.dart';
import 'package:wyrm_desk/features/sharing/sharing_server_section.dart';
import 'package:wyrm_desk/features/sharing/sharing_service.dart';
import 'package:wyrm_desk/server/web_server.dart';

void main() {
  group('SharingServerSection HTTP auth, upload & Range download', () {
    late Directory tempRoot;
    late SharingAuthService auth;
    late ShelfWebServer server;
    late int revision;
    late bool hasPermission;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('wyrm_sharing_srv_');
      auth = SharingAuthService(random: Random(7));
      revision = 0;
      hasPermission = true;
      server = ShelfWebServer(
        htmlOverride: '<html></html>',
        cssOverride: '',
        jsOverride: '',
        faviconOverride: <int>[1, 2, 3],
        sections: [
          SharingServerSection(
            auth: auth,
            service: const SharingService(),
            getHasPermission: () => hasPermission,
            getRootPath: () => tempRoot.path,
            getRevision: () => revision,
            onExternalMutation: () => revision++,
          ),
        ],
      );
      await server.start(port: 0);
    });

    tearDown(() async {
      await server.stop();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

    test('rejects unauthenticated requests and hides file names in /api/status', () async {
      await File('${tempRoot.path}${Platform.pathSeparator}secret.txt')
          .writeAsString('top-secret');

      final statusRes = await http.get(url('/api/status'));
      expect(statusRes.statusCode, 200);
      final statusJson = jsonDecode(statusRes.body) as Map<String, dynamic>;
      final sharingSlice = statusJson['sharing'] as Map<String, dynamic>;
      expect(sharingSlice['locked'], isTrue);
      expect(sharingSlice.containsKey('files'), isFalse);

      final filesRes = await http.get(url('/api/sharing/files'));
      expect(filesRes.statusCode, 401);

      final badAuth = await http.post(
        url('/api/sharing/auth'),
        body: jsonEncode(<String, String>{'password': 'NOPE'}),
      );
      expect(badAuth.statusCode, 401);
    });

    test('authenticates, streams upload, and serves full + Range 206 download', () async {
      final authRes = await http.post(
        url('/api/sharing/auth'),
        body: jsonEncode(<String, String>{'password': auth.activePassword}),
      );
      expect(authRes.statusCode, 200);
      final token =
          (jsonDecode(authRes.body) as Map<String, dynamic>)['token'] as String;

      final uploadRes = await http.post(
        url('/api/sharing/upload'),
        headers: <String, String>{
          'X-Sharing-Token': token,
          'X-File-Name': Uri.encodeComponent('sample data.bin'),
        },
        body: utf8.encode('0123456789'),
      );
      expect(uploadRes.statusCode, 201);
      expect(revision, 1);

      final fullRes = await http.get(
        url(
          '/api/sharing/download?path=${Uri.encodeComponent('sample data.bin')}&token=$token',
        ),
      );
      expect(fullRes.statusCode, 200);
      expect(fullRes.body, '0123456789');

      final rangeRes = await http.get(
        url(
          '/api/sharing/download?path=${Uri.encodeComponent('sample data.bin')}&token=$token',
        ),
        headers: const <String, String>{'Range': 'bytes=2-5'},
      );
      expect(rangeRes.statusCode, 206);
      expect(rangeRes.headers['content-range'], 'bytes 2-5/10');
      expect(rangeRes.body, '2345');
    });
  });
}
