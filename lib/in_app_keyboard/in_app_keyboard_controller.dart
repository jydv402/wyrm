import 'package:flutter/material.dart';

/// Keyboard layout modes supported by the virtual keyboard.
enum VirtualKeyboardMode {
  letters,
  symbols,
  numpad,
}

/// Controller managing virtual keyboard state, text insertion, cursor manipulation,
/// and active text editing field attachments.
class InAppKeyboardController extends ChangeNotifier {
  TextEditingController? _activeTextController;
  FocusNode? _activeFocusNode;
  TextInputType _inputType = TextInputType.text;
  VirtualKeyboardMode _mode = VirtualKeyboardMode.letters;
  bool _isShifted = false;
  bool _isCapsLock = false;
  VoidCallback? onActionPressed;

  TextEditingController? get activeTextController => _activeTextController;
  FocusNode? get activeFocusNode => _activeFocusNode;
  TextInputType get inputType => _inputType;
  VirtualKeyboardMode get mode => _mode;
  bool get isShifted => _isShifted || _isCapsLock;
  bool get isCapsLock => _isCapsLock;
  bool get hasActiveField => _activeTextController != null;

  /// Attaches a text editing controller and focus node to the virtual keyboard.
  void attach({
    required TextEditingController textController,
    required FocusNode focusNode,
    TextInputType inputType = TextInputType.text,
  }) {
    if (_activeTextController == textController && _activeFocusNode == focusNode) {
      return;
    }
    _activeTextController = textController;
    _activeFocusNode = focusNode;
    _inputType = inputType;

    if (inputType == TextInputType.number ||
        inputType == TextInputType.phone ||
        inputType == const TextInputType.numberWithOptions(decimal: true, signed: true)) {
      _mode = VirtualKeyboardMode.numpad;
    } else if (_mode == VirtualKeyboardMode.numpad) {
      _mode = VirtualKeyboardMode.letters;
    }
    notifyListeners();
  }

  /// Detaches the current text controller if it matches the target.
  void detach(TextEditingController textController) {
    if (_activeTextController == textController) {
      _activeTextController = null;
      _activeFocusNode = null;
      notifyListeners();
    }
  }

  /// Changes the current layout mode of the keyboard.
  void setMode(VirtualKeyboardMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      notifyListeners();
    }
  }

  /// Toggles the shift state for capital letters.
  void toggleShift() {
    _isShifted = !_isShifted;
    notifyListeners();
  }

  /// Toggles caps lock mode.
  void toggleCapsLock() {
    _isCapsLock = !_isCapsLock;
    _isShifted = false;
    notifyListeners();
  }

  /// Inserts a string or character into the active text field.
  void insertText(String text) {
    final controller = _activeTextController;
    if (controller == null) return;

    final value = controller.value;
    final selection = value.selection;
    final textToInsert = isShifted ? text.toUpperCase() : text.toLowerCase();

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = value.text.length;
      end = value.text.length;
    }

    final newText = value.text.replaceRange(start, end, textToInsert);
    final newSelectionIndex = start + textToInsert.length;

    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
      composing: TextRange.empty,
    );

    if (_isShifted && !_isCapsLock) {
      _isShifted = false;
    }
    notifyListeners();
  }

  /// Performs backspace deletion in the active text field.
  void backspace() {
    final controller = _activeTextController;
    if (controller == null) return;

    final value = controller.value;
    final selection = value.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = value.text.length;
      end = value.text.length;
    }

    if (start != end) {
      final newText = value.text.replaceRange(start, end, '');
      controller.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
    } else if (start > 0) {
      final newText = value.text.replaceRange(start - 1, start, '');
      controller.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 1),
        composing: TextRange.empty,
      );
    }
    notifyListeners();
  }

  /// Clears all text in the active text field.
  void clear() {
    final controller = _activeTextController;
    if (controller == null) return;

    controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    notifyListeners();
  }

  /// Moves cursor one character to the left.
  void moveCursorLeft() {
    final controller = _activeTextController;
    if (controller == null) return;

    final selection = controller.selection;
    final currentOffset = selection.baseOffset;
    if (currentOffset > 0) {
      controller.selection = TextSelection.collapsed(offset: currentOffset - 1);
      notifyListeners();
    }
  }

  /// Moves cursor one character to the right.
  void moveCursorRight() {
    final controller = _activeTextController;
    if (controller == null) return;

    final selection = controller.selection;
    final currentOffset = selection.baseOffset;
    if (currentOffset < controller.text.length) {
      controller.selection = TextSelection.collapsed(offset: currentOffset + 1);
      notifyListeners();
    }
  }

  /// Submits the current form or triggers the action callback.
  void submit() {
    onActionPressed?.call();
  }
}
