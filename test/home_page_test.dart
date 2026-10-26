import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/clock/clock.dart';
import 'package:wyrm_desk/home/home.dart';
import 'package:wyrm_desk/tasks/tasks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'HomePage enables immersiveSticky mode on mount and restores on dispose',
      (WidgetTester tester) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      },
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    // Verify immersiveSticky was called on mount
    expect(
      log.any((call) =>
          call.method == 'SystemChrome.setEnabledSystemUIMode' &&
          call.arguments == 'SystemUiMode.immersiveSticky'),
      isTrue,
    );

    // Verify HomePage is present
    expect(find.byType(HomePage), findsOneWidget);

    // Simulate lifecycle change to resumed
    log.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      log.any((call) =>
          call.method == 'SystemChrome.setEnabledSystemUIMode' &&
          call.arguments == 'SystemUiMode.immersiveSticky'),
      isTrue,
    );

    // Dispose HomePage by pumping a different widget
    log.clear();
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(),
      ),
    );

    expect(
      log.any((call) =>
          call.method == 'SystemChrome.setEnabledSystemUIMode' &&
          call.arguments == 'SystemUiMode.edgeToEdge'),
      isTrue,
    );
  });

  testWidgets(
      'HomePage auto-scrolls to target card upon receiving CardScrollRequest',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        clockTimeProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 9, 17, 10, 0)),
        ),
        cardLayoutProvider.overrideWith(
          () => _CustomCardLayoutNotifier(
            const CardLayoutConfig(
              clock: CardSize.fullscreen,
              habits: CardSize.fullscreen,
              calendar: CardSize.fullscreen,
              tasks: CardSize.fullscreen,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HomePage(
            clockWidget: SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(scrollableFinder, findsOneWidget);

    final scrollableState = Scrollable.of(tester.element(find.byType(TasksCard)));
    final initialOffset = scrollableState.position.pixels;
    expect(initialOffset, 0.0);

    // Request scroll to tasks card
    container
        .read(cardScrollRequestProvider.notifier)
        .requestScroll(DashboardCardType.tasks);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final newOffset = scrollableState.position.pixels;
    expect(newOffset, greaterThan(0.0));

    // Dispose HomePage and its child timers
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(),
      ),
    );
  });
}

class _CustomCardLayoutNotifier extends CardLayoutNotifier {
  final CardLayoutConfig _initial;
  _CustomCardLayoutNotifier(this._initial);

  @override
  CardLayoutConfig build() => _initial;
}
