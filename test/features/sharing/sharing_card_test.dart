import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/data/repositories/settings_repository.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/sharing/sharing_card.dart';
import 'package:wyrm_desk/features/sharing/sharing_models.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/features/sharing/sharing_service.dart';
import 'package:wyrm_desk/native/sharing_gateway.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/theme/theme.dart';

class _InMemorySettingsRepository implements SettingsRepository {
  @override
  Future<AppSettingsConfig> loadSettings() async => const AppSettingsConfig();

  @override
  Future<void> saveSettings(AppSettingsConfig next) async {}
}

class _FakeSharingService extends SharingService {
  final List<SharedFileEntry> entries;
  const _FakeSharingService(this.entries);

  @override
  Future<SharingResult<void>> ensureDirectoryExists(String rootPath) async =>
      const SharingSuccess<void>(null);

  @override
  Future<SharingResult<List<SharedFileEntry>>> listDirectory(
    String rootPath,
    String relativePath, {
    SharingSortField sortBy = SharingSortField.name,
    bool ascending = true,
  }) async => SharingSuccess<List<SharedFileEntry>>(entries);
}

void main() {
  group('SharingCard widget states', () {
    Widget buildHarness({
      required FakeSharingGateway gateway,
      required CardSize size,
      List<SharedFileEntry> entries = const <SharedFileEntry>[],
    }) {
      return ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _InMemorySettingsRepository(),
          ),
          sharingGatewayProvider.overrideWithValue(gateway),
          sharingServiceProvider.overrideWithValue(
            _FakeSharingService(entries),
          ),
          localIpProvider.overrideWith((ref) async => '192.168.1.50'),
          webServerProvider.overrideWithValue(
            ShelfWebServer(sections: const []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: 520,
              child: SharingCard(currentSize: size),
            ),
          ),
        ),
      );
    }

    testWidgets('shows permission gate when All Files Access is denied', (
      tester,
    ) async {
      final gateway = FakeSharingGateway(allFilesAccessGranted: false);
      await tester.pumpWidget(
        buildHarness(gateway: gateway, size: CardSize.small),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Files Access Required'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('sharing_grant_access_button')),
        findsOneWidget,
      );
    });

    testWidgets('renders file browser in medium tier when access is granted', (
      tester,
    ) async {
      final gateway = FakeSharingGateway(allFilesAccessGranted: true);
      final fakeEntries = <SharedFileEntry>[
        SharedFileEntry(
          name: 'notes.txt',
          relativePath: 'notes.txt',
          isDirectory: false,
          sizeBytes: 128,
          modifiedAtUtc: DateTime.utc(2026, 11, 27),
          mimeType: 'text/plain; charset=utf-8',
        ),
      ];

      await tester.pumpWidget(
        buildHarness(
          gateway: gateway,
          size: CardSize.medium,
          entries: fakeEntries,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Shared'), findsOneWidget);
    });

    testWidgets(
      'renders horizontal summary and controls in small 1.75:1 tier when access is granted',
      (tester) async {
        final gateway = FakeSharingGateway(allFilesAccessGranted: true);
        final fakeEntries = <SharedFileEntry>[
          SharedFileEntry(
            name: 'notes.txt',
            relativePath: 'notes.txt',
            isDirectory: false,
            sizeBytes: 2048,
            modifiedAtUtc: DateTime.utc(2026, 11, 27),
            mimeType: 'text/plain; charset=utf-8',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(
                _InMemorySettingsRepository(),
              ),
              sharingGatewayProvider.overrideWithValue(gateway),
              sharingServiceProvider.overrideWithValue(
                _FakeSharingService(fakeEntries),
              ),
              localIpProvider.overrideWith((ref) async => '192.168.1.50'),
              webServerProvider.overrideWithValue(
                ShelfWebServer(sections: const []),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SizedBox(
                  width: 595,
                  height: 340,
                  child: SharingCard(currentSize: CardSize.small),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 file · 0 folders'), findsOneWidget);
        expect(find.text('http://192.168.1.50:8081'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('sharing_small_qr_button')),
          findsOneWidget,
        );
      },
    );
  });
}
