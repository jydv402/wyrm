import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

void main() {
  group('DuskGlassButton', () {
    testWidgets('renders icon and label correctly and handles tap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DuskGlassButton(
                onPressed: () => tapped = true,
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byType(DuskGlassButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('DuskGlassButton.icon renders centered without Row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DuskGlassButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.settings),
                size: 36,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      final size = tester.getSize(find.byType(DuskGlassButton));
      expect(size.width, equals(36));
      expect(size.height, equals(36));
    });

    testWidgets(
      'does not trigger RenderFlex overflow when label exceeds tight constraints',
      (WidgetTester tester) async {
        // In the previous implementation, placing an icon + label in a tight box
        // threw a RenderFlex overflow because the label was unconstrained inside the Row.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 100,
                  child: DuskGlassButton(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Download Very Long Update Title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(DuskGlassButton), findsOneWidget);
      },
    );

    testWidgets(
      'does not throw BoxConstraints.lerp assertion when transitioning between finite and unbounded width',
      (WidgetTester tester) async {
        // Toggling between an icon-only button (finite width: size) and
        // a labeled button (unbounded width: null) in the same widget slot.
        // Previously, AnimatedContainer would attempt to animate constraints
        // from BoxConstraints(maxWidth: 32) to BoxConstraints(maxWidth: infinity)
        // and throw: "Cannot interpolate between finite constraints and unbounded constraints."
        bool isIconOnly = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => isIconOnly = !isIconOnly),
                        child: const Text('Toggle'),
                      ),
                      if (isIconOnly)
                        DuskGlassButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.close),
                          size: 32,
                        )
                      else
                        DuskGlassButton(
                          onPressed: () {},
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Check for Updates'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.text('Check for Updates'), findsNothing);

        // Toggle to labeled button
        await tester.tap(find.text('Toggle'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Check for Updates'), findsOneWidget);

        // Toggle back to icon-only button
        await tester.tap(find.text('Toggle'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );
  });
}
