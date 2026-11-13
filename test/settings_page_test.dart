import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/settings/settings_page.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

void main() {
  group('SettingsPage Widget Tests', () {
    testWidgets(
      'renders full-screen layout with top bar and Dusk Glass sections',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localIpProvider.overrideWith(
                (ref) => Future.value('192.168.1.50'),
              ),
            ],
            child: const MaterialApp(home: SettingsPage()),
          ),
        );
        await tester.pumpAndSettle();

        // Top Bar
        expect(find.text('Settings'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Section Headers
        expect(find.text('Display & Brightness'), findsOneWidget);
        expect(find.text('Clock & Calendar'), findsOneWidget);
        expect(find.text('Card Appearance'), findsOneWidget);
        expect(find.text('Web Remote Companion'), findsOneWidget);
        expect(find.text('Data & Backups'), findsOneWidget);

        // Sections Content
        expect(
          find.text('Screen intensity of the tablet ambient display'),
          findsOneWidget,
        );
        expect(
          find.text('Pitch-black ultra-low glare glowing clock for bedtime'),
          findsOneWidget,
        );
        expect(find.text('Time Format'), findsOneWidget);
        expect(find.text('Week Starts On'), findsOneWidget);
        expect(find.text('Card Font Size'), findsOneWidget);
        expect(find.text('Server Running'), findsOneWidget);
        expect(find.text('http://192.168.1.50:8081'), findsOneWidget);
        expect(find.text('Show QR'), findsOneWidget);
        expect(find.text('Export to Downloads'), findsOneWidget);
        expect(find.text('Import from Downloads'), findsOneWidget);
      },
    );

    testWidgets(
      'toggles 12-hour and 24-hour time format via segmented control',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(appSettingsProvider).is24HourFormat, false);

        // Tap 24-hour segment
        await tester.tap(find.text('24-hour'));
        await tester.pumpAndSettle();

        expect(container.read(appSettingsProvider).is24HourFormat, true);

        // Tap 12-hour segment
        await tester.tap(find.text('12-hour'));
        await tester.pumpAndSettle();

        expect(container.read(appSettingsProvider).is24HourFormat, false);
      },
    );

    testWidgets('toggles week start day via segmented control', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(appSettingsProvider).startWeekOnMonday, false);

      // Tap Monday segment
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();

      expect(container.read(appSettingsProvider).startWeekOnMonday, true);

      // Tap Sunday segment
      await tester.tap(find.text('Sunday'));
      await tester.pumpAndSettle();

      expect(container.read(appSettingsProvider).startWeekOnMonday, false);
    });

    testWidgets('toggles nightstand mode switch', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(cardLayoutProvider).clock,
        isNot(CardSize.nightstand),
      );

      // Find switch
      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);

      // Toggle Nightstand Switch
      await tester.tap(switches.first);
      await tester.pumpAndSettle();
      expect(container.read(cardLayoutProvider).clock, CardSize.nightstand);
    });

    testWidgets('adjusts brightness slider and updates displayProvider state', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(2)); // Brightness slider + Font size slider

      // Adjust Brightness Slider
      final brightnessSlider = sliders.first;
      await tester.tap(brightnessSlider);
      await tester.pumpAndSettle();

      expect(
        container.read(displayProvider).brightness,
        inInclusiveRange(0.05, 1.0),
      );
    });

    testWidgets('tapping Show QR button opens NetworkConnectionModal', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localIpProvider.overrideWith(
              (ref) => Future.value('192.168.1.100'),
            ),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final showQrFinder = find.text('Show QR');
      expect(showQrFinder, findsOneWidget);

      await tester.ensureVisible(showQrFinder);
      await tester.pumpAndSettle();
      await tester.tap(showQrFinder);
      await tester.pumpAndSettle();

      expect(find.byType(NetworkConnectionModal), findsOneWidget);
      expect(find.text('Connect from your phone or laptop'), findsOneWidget);
    });

    testWidgets('renders cleanly on narrow viewports without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Display & Brightness'), findsOneWidget);
      expect(find.text('Clock & Calendar'), findsOneWidget);
      expect(find.text('Card Appearance'), findsOneWidget);
      expect(find.text('Web Remote Companion'), findsOneWidget);
      expect(find.text('Data & Backups'), findsOneWidget);
    });
    testWidgets(
      'all cards inside SettingsPage use the Glacier DuskTone theme',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localIpProvider.overrideWith((ref) => Future.value('127.0.0.1')),
            ],
            child: const MaterialApp(home: SettingsPage()),
          ),
        );
        await tester.pumpAndSettle();

        final panels = tester.widgetList<DuskGlassPanel>(
          find.byType(DuskGlassPanel),
        );
        expect(panels, isNotEmpty);
        expect(panels.length, 5);

        for (final panel in panels) {
          expect(panel.tone, AppColors.glacier);
          expect(panel.tone.accent, AppColors.glacierAccent);
          expect(panel.tone.fill, AppColors.glacierFill);
        }
      },
    );
  });
}
