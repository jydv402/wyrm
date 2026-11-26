import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/data/repositories/settings_repository.dart';
import 'package:wyrm_desk/features/sharing/sharing_auth.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/features/sharing/sharing_path.dart';
import 'package:wyrm_desk/features/sharing/sharing_service.dart';
import 'package:wyrm_desk/native/sharing_gateway.dart';

class _InMemorySettingsRepo implements SettingsRepository {
  AppSettingsConfig config;
  _InMemorySettingsRepo(this.config);

  @override
  Future<AppSettingsConfig> loadSettings() async => config;

  @override
  Future<void> saveSettings(AppSettingsConfig next) async {
    config = next;
  }
}

void main() {
  group('SharingPath traversal & collision guards', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('wyrm_sharing_path_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('rejects traversal escapes, absolute paths, and null bytes', () {
      expect(SharingPath.resolveSafePath(tempRoot.path, '../secret'), isNull);
      expect(
        SharingPath.resolveSafePath(tempRoot.path, 'sub/../../etc'),
        isNull,
      );
      expect(SharingPath.resolveSafePath(tempRoot.path, '/etc/passwd'), isNull);
      expect(SharingPath.resolveSafePath(tempRoot.path, 'C:\\Windows'), isNull);
      expect(SharingPath.resolveSafePath(tempRoot.path, 'bad\x00name'), isNull);
      expect(
        SharingPath.resolveSafePath(tempRoot.path, 'docs/notes.txt'),
        isNotNull,
      );
    });

    test('uniqueTargetFilePath increments suffix on collisions', () async {
      final sep = Platform.pathSeparator;
      await File('${tempRoot.path}${sep}photo.jpg').writeAsString('v0');
      final first = SharingPath.uniqueTargetFilePath(
        tempRoot.path,
        'photo.jpg',
      );
      expect(first.endsWith('${sep}photo (1).jpg'), isTrue);

      await File(first).writeAsString('v1');
      final second = SharingPath.uniqueTargetFilePath(
        tempRoot.path,
        'photo.jpg',
      );
      expect(second.endsWith('${sep}photo (2).jpg'), isTrue);
    });
  });

  group('SharingAuthService', () {
    test(
      'generates 6-char code, issues tokens, and revokes on password change',
      () {
        final auth = SharingAuthService(random: Random(42));
        expect(auth.activePassword.length, 6);
        expect(auth.isCustomPassword, isFalse);

        expect(auth.authenticate('WRONG1'), isNull);
        final token = auth.authenticate(auth.activePassword);
        expect(token, isNotNull);
        expect(auth.isValidToken(token), isTrue);

        auth.setCustomPassword('desk99');
        expect(auth.isCustomPassword, isTrue);
        expect(auth.isValidToken(token), isFalse);

        final customToken = auth.authenticate('desk99');
        expect(auth.isValidToken(customToken), isTrue);

        final regenerated = auth.regeneratePassword();
        expect(regenerated.length, 6);
        expect(auth.isCustomPassword, isFalse);
        expect(auth.isValidToken(customToken), isFalse);
      },
    );
  });

  group('SharingService filesystem CRUD & stream upload', () {
    late Directory tempRoot;
    const service = SharingService();

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('wyrm_sharing_svc_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test(
      'supports stream upload, collision rename, mkdir, rename, move, delete',
      () async {
        final upload1 = await service.receiveStreamUpload(
          tempRoot.path,
          '',
          'hello.txt',
          Stream<List<int>>.fromIterable(<List<int>>[utf8.encode('first')]),
        );
        expect(upload1, isA<SharingSuccess<SharedFileEntry>>());
        expect(
          (upload1 as SharingSuccess<SharedFileEntry>).value.name,
          'hello.txt',
        );

        final upload2 = await service.receiveStreamUpload(
          tempRoot.path,
          '',
          'hello.txt',
          Stream<List<int>>.fromIterable(<List<int>>[utf8.encode('second')]),
        );
        expect(
          (upload2 as SharingSuccess<SharedFileEntry>).value.name,
          'hello (1).txt',
        );

        final dirRes = await service.createDirectory(
          tempRoot.path,
          '',
          'inbox',
        );
        expect(dirRes, isA<SharingSuccess<SharedFileEntry>>());

        final moveRes = await service.moveEntry(
          tempRoot.path,
          'hello (1).txt',
          'inbox',
        );
        expect(
          (moveRes as SharingSuccess<SharedFileEntry>).value.relativePath,
          'inbox/hello (1).txt',
        );

        final renameRes = await service.renameEntry(
          tempRoot.path,
          'inbox/hello (1).txt',
          'renamed.txt',
        );
        expect(
          (renameRes as SharingSuccess<SharedFileEntry>).value.relativePath,
          'inbox/renamed.txt',
        );

        final listRes = await service.listDirectory(tempRoot.path, 'inbox');
        final entries =
            (listRes as SharingSuccess<List<SharedFileEntry>>).value;
        expect(entries.map((e) => e.name), <String>['renamed.txt']);

        final delRes = await service.deleteEntry(tempRoot.path, 'inbox');
        expect(delRes, isA<SharingSuccess<void>>());

        final rootList = await service.listDirectory(tempRoot.path, '');
        expect(
          (rootList as SharingSuccess<List<SharedFileEntry>>).value
              .map((e) => e.name)
              .toList(),
          <String>['hello.txt'],
        );
      },
    );

    test('listDirectory auto-creates missing root while rejecting missing subfolders', () async {
      final missingRoot =
          '${tempRoot.path}${Platform.pathSeparator}nested${Platform.pathSeparator}Wyrm';
      expect(await Directory(missingRoot).exists(), isFalse);

      final rootRes = await service.listDirectory(missingRoot, '');
      expect(rootRes, isA<SharingSuccess<List<SharedFileEntry>>>());
      expect(await Directory(missingRoot).exists(), isTrue);

      final subRes = await service.listDirectory(missingRoot, 'missing_sub');
      expect(subRes, isA<SharingError<List<SharedFileEntry>>>());
      expect(
        (subRes as SharingError<List<SharedFileEntry>>).failure,
        isA<SharingNotFound>(),
      );
    });
  });

  group('SharingNotifier auto directory initialization', () {
    test('creates default folder once permission is granted even with device browse enabled', () async {
      final tempBase = await Directory.systemTemp.createTemp('wyrm_notifier_');
      addTearDown(() async {
        if (await tempBase.exists()) {
          await tempBase.delete(recursive: true);
        }
      });

      final defaultDir =
          '${tempBase.path}${Platform.pathSeparator}Download${Platform.pathSeparator}Wyrm';
      final gateway = FakeSharingGateway(
        allFilesAccessGranted: false,
        defaultRootPath: defaultDir,
        deviceBrowseRootPath: tempBase.path,
      );
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _InMemorySettingsRepo(
              const AppSettingsConfig(sharingAllowDeviceBrowse: true),
            ),
          ),
          sharingGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      container.read(sharingProvider);
      await container
          .read(sharingProvider.notifier)
          .refreshPermissionAndDirectory();
      expect(await Directory(defaultDir).exists(), isFalse);

      gateway.allFilesAccessGranted = true;
      await container
          .read(sharingProvider.notifier)
          .refreshPermissionAndDirectory();

      expect(await Directory(defaultDir).exists(), isTrue);
      expect(container.read(sharingProvider).hasPermission, isTrue);
      expect(container.read(sharingProvider).activeRootPath, tempBase.path);
    });
  });
}
