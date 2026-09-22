import 'package:flutter/material.dart';
import 'in_app_keyboard_scope.dart';

/// An adaptive text input field that seamlessly binds to the virtual in-app keyboard
/// when wrapped inside an [InAppKeyboardScope], and falls back to standard platform IME
/// when used elsewhere (such as in classic modal sheets).
class InAppKeyboardTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextInputType keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color? cursorColor;
  final int? maxLines;

  const InAppKeyboardTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.cursorColor,
    this.maxLines = 1,
  });

  @override
  State<InAppKeyboardTextField> createState() => _InAppKeyboardTextFieldState();
}

class _InAppKeyboardTextFieldState extends State<InAppKeyboardTextField> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_handleTextChange);
    _effectiveFocusNode.addListener(_handleFocusChange);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _effectiveFocusNode.requestFocus();
        _attachToVirtualKeyboard();
      });
    }
  }

  @override
  void didUpdateWidget(InAppKeyboardTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      _effectiveController.addListener(_handleTextChange);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleTextChange);
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    widget.onChanged?.call(_effectiveController.text);
  }

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus) {
      _attachToVirtualKeyboard();
    }
  }

  void _attachToVirtualKeyboard() {
    final keyboardController = InAppKeyboardScope.maybeOf(context);
    if (keyboardController != null) {
      keyboardController.attach(
        textController: _effectiveController,
        focusNode: _effectiveFocusNode,
        inputType: widget.keyboardType,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inVirtualScope = InAppKeyboardScope.maybeOf(context) != null;

    return TextField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      readOnly: inVirtualScope,
      showCursor: true,
      enableInteractiveSelection: true,
      keyboardType: widget.keyboardType,
      cursorColor: widget.cursorColor,
      style: widget.style,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      onTap: () {
        if (inVirtualScope) {
          _attachToVirtualKeyboard();
        }
      },
      onSubmitted: widget.onSubmitted,
    );
  }
}
