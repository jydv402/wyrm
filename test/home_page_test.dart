import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/home/home.dart';

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
}
