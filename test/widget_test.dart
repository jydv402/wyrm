import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/main.dart';

void main() {
  testWidgets('WyrmDeskApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WyrmDeskApp());
    expect(find.text('Wyrm Desk Companion'), findsOneWidget);
  });
}
