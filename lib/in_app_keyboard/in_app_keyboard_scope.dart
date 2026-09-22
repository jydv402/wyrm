import 'package:flutter/material.dart';
import 'in_app_keyboard_controller.dart';

/// Scoped inherited notifier providing the virtual keyboard controller down the widget tree.
class InAppKeyboardScope extends InheritedNotifier<InAppKeyboardController> {
  const InAppKeyboardScope({
    super.key,
    required InAppKeyboardController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Retrieves the keyboard controller from the nearest ancestor scope, throwing if not found.
  static InAppKeyboardController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<InAppKeyboardScope>();
    assert(scope != null, 'No InAppKeyboardScope found in context');
    return scope!.notifier!;
  }

  /// Safely retrieves the keyboard controller from ancestor scope, or null if outside keyboard context.
  static InAppKeyboardController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InAppKeyboardScope>()?.notifier;
  }
}
