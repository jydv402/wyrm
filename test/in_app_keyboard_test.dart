import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/in_app_keyboard/in_app_keyboard.dart';

void main() {
  group('InAppKeyboardController Unit Tests', () {
    test('inserts lowercase and uppercase text based on shift and caps lock', () {
      final controller = InAppKeyboardController();
      final textEditingController = TextEditingController();
      final focusNode = FocusNode();

      controller.attach(
        textController: textEditingController,
        focusNode: focusNode,
      );

      controller.insertText('h');
      expect(textEditingController.text, 'h');

      controller.toggleShift();
      expect(controller.isShifted, true);
      controller.insertText('i');
      expect(textEditingController.text, 'hI');
      expect(controller.isShifted, false);

      controller.toggleCapsLock();
      expect(controller.isCapsLock, true);
      expect(controller.isShifted, true);
      controller.insertText('a');
      controller.insertText('b');
      expect(textEditingController.text, 'hIAB');

      controller.toggleCapsLock();
      expect(controller.isCapsLock, false);
      expect(controller.isShifted, false);

      textEditingController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    test('backspace deletes single characters and selected ranges', () {
      final controller = InAppKeyboardController();
      final textEditingController = TextEditingController(text: 'Hello');
      final focusNode = FocusNode();

      controller.attach(
        textController: textEditingController,
        focusNode: focusNode,
      );

      textEditingController.selection = const TextSelection.collapsed(offset: 5);
      controller.backspace();
      expect(textEditingController.text, 'Hell');

      textEditingController.selection =
          const TextSelection(baseOffset: 1, extentOffset: 3);
      controller.backspace();
      expect(textEditingController.text, 'Hl');

      controller.clear();
      expect(textEditingController.text, '');

      textEditingController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    test('cursor movement left and right adjusts selection offset', () {
      final controller = InAppKeyboardController();
      final textEditingController = TextEditingController(text: 'Cat');
      final focusNode = FocusNode();

      controller.attach(
        textController: textEditingController,
        focusNode: focusNode,
      );

      textEditingController.selection = const TextSelection.collapsed(offset: 3);
      controller.moveCursorLeft();
      expect(textEditingController.selection.baseOffset, 2);

      controller.moveCursorLeft();
      expect(textEditingController.selection.baseOffset, 1);

      controller.moveCursorRight();
      expect(textEditingController.selection.baseOffset, 2);

      textEditingController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    test('automatically sets numpad mode when numeric input type is attached', () {
      final controller = InAppKeyboardController();
      final textEditingController = TextEditingController();
      final focusNode = FocusNode();

      controller.attach(
        textController: textEditingController,
        focusNode: focusNode,
        inputType: TextInputType.number,
      );

      expect(controller.mode, VirtualKeyboardMode.numpad);

      controller.setMode(VirtualKeyboardMode.letters);
      expect(controller.mode, VirtualKeyboardMode.letters);

      textEditingController.dispose();
      focusNode.dispose();
      controller.dispose();
    });
  });

  group('InAppKeyboardWidget UI Tests', () {
    testWidgets('renders virtual keyboard and types into scoped text field',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final keyboardController = InAppKeyboardController();
      final textController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: InAppKeyboardScope(
            controller: keyboardController,
            child: Scaffold(
              body: Column(
                children: [
                  InAppKeyboardTextField(
                    controller: textController,
                    autofocus: true,
                  ),
                  InAppKeyboardWidget(controller: keyboardController),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final aKeyFinder = find.widgetWithText(InkWell, 'a');
      expect(aKeyFinder, findsOneWidget);
      await tester.tap(aKeyFinder);
      await tester.pumpAndSettle();
      expect(textController.text, 'a');

      final bKeyFinder = find.widgetWithText(InkWell, 'b');
      await tester.tap(bKeyFinder);
      await tester.pumpAndSettle();
      expect(textController.text, 'ab');

      final spaceFinder = find.byWidgetPredicate(
        (widget) => widget is InkWell && widget.child is Container,
      );
      expect(spaceFinder, findsWidgets);

      final symbolsButtonFinder = find.widgetWithText(InkWell, '?123');
      expect(symbolsButtonFinder, findsOneWidget);
      await tester.tap(symbolsButtonFinder);
      await tester.pumpAndSettle();
      expect(keyboardController.mode, VirtualKeyboardMode.symbols);

      final oneKeyFinder = find.widgetWithText(InkWell, '1');
      expect(oneKeyFinder, findsOneWidget);
      await tester.tap(oneKeyFinder);
      await tester.pumpAndSettle();
      expect(textController.text, 'ab1');

      final backspaceFinder = find.byIcon(Icons.backspace_outlined);
      expect(backspaceFinder, findsOneWidget);
      await tester.tap(backspaceFinder);
      await tester.pumpAndSettle();
      expect(textController.text, 'ab');

      final abcButtonFinder = find.widgetWithText(InkWell, 'ABC');
      expect(abcButtonFinder, findsOneWidget);
      await tester.tap(abcButtonFinder);
      await tester.pumpAndSettle();
      expect(keyboardController.mode, VirtualKeyboardMode.letters);

      textController.dispose();
      keyboardController.dispose();
    });

    testWidgets('InAppKeyboardTextField sets readOnly when inside scope and false when outside',
        (WidgetTester tester) async {
      final controller = InAppKeyboardController();

      await tester.pumpWidget(
        MaterialApp(
          home: InAppKeyboardScope(
            controller: controller,
            child: const Scaffold(
              body: InAppKeyboardTextField(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scopedTextField = tester.widget<TextField>(find.byType(TextField));
      expect(scopedTextField.readOnly, true);
      expect(scopedTextField.showCursor, true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InAppKeyboardTextField(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unscopedTextField = tester.widget<TextField>(find.byType(TextField));
      expect(unscopedTextField.readOnly, false);

      controller.dispose();
    });
  });
}
