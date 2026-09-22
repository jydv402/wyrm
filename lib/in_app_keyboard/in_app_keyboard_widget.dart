import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'in_app_keyboard_controller.dart';
import 'in_app_keyboard_scope.dart';

/// Ergonomic, touch-first in-app virtual keyboard widget.
/// Designed for tablet form factors with tactile key styling and discrete
/// letter, symbol, and numeric keypad layouts.
class InAppKeyboardWidget extends StatelessWidget {
  final InAppKeyboardController? controller;
  final double height;
  final VoidCallback? onDonePressed;

  const InAppKeyboardWidget({
    super.key,
    this.controller,
    this.height = 236.0,
    this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveController =
        controller ?? InAppKeyboardScope.maybeOf(context);

    if (effectiveController == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: effectiveController,
      builder: (context, _) {
        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildLayoutForMode(context, effectiveController),
        );
      },
    );
  }

  Widget _buildLayoutForMode(
    BuildContext context,
    InAppKeyboardController kb,
  ) {
    switch (kb.mode) {
      case VirtualKeyboardMode.letters:
        return _buildLettersLayout(context, kb);
      case VirtualKeyboardMode.symbols:
        return _buildSymbolsLayout(context, kb);
      case VirtualKeyboardMode.numpad:
        return _buildNumpadLayout(context, kb);
    }
  }

  Widget _buildLettersLayout(BuildContext context, InAppKeyboardController kb) {
    const row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    const row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    const row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return Column(
      children: [
        // Row 1
        Expanded(
          child: Row(
            children: row1.map((char) {
              final label = kb.isShifted ? char.toUpperCase() : char;
              return Expanded(
                child: _KeyButton(
                  label: label,
                  onTap: () => kb.insertText(char),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 5),

        // Row 2
        Expanded(
          child: Row(
            children: [
              const Spacer(flex: 1),
              ...row2.map((char) {
                final label = kb.isShifted ? char.toUpperCase() : char;
                return Expanded(
                  flex: 2,
                  child: _KeyButton(
                    label: label,
                    onTap: () => kb.insertText(char),
                  ),
                );
              }),
              const Spacer(flex: 1),
            ],
          ),
        ),
        const SizedBox(height: 5),

        // Row 3: Shift, Z-M, Backspace
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _ActionKeyButton(
                  icon: kb.isCapsLock
                      ? Icons.keyboard_capslock_rounded
                      : Icons.arrow_upward_rounded,
                  isActive: kb.isShifted,
                  activeColor: AppColors.accentOrange,
                  onTap: kb.toggleShift,
                  onLongPress: kb.toggleCapsLock,
                ),
              ),
              ...row3.map((char) {
                final label = kb.isShifted ? char.toUpperCase() : char;
                return Expanded(
                  flex: 2,
                  child: _KeyButton(
                    label: label,
                    onTap: () => kb.insertText(char),
                  ),
                );
              }),
              Expanded(
                flex: 3,
                child: _ActionKeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: kb.backspace,
                  onLongPress: kb.clear,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),

        // Row 4: Mode switch, Cursor nudges, Spacebar, Done
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _ActionKeyButton(
                  label: '?123',
                  onTap: () => kb.setMode(VirtualKeyboardMode.symbols),
                ),
              ),
              Expanded(
                flex: 2,
                child: _ActionKeyButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: kb.moveCursorLeft,
                ),
              ),
              Expanded(
                flex: 7,
                child: _KeyButton(
                  label: 'space',
                  isSpacebar: true,
                  onTap: () => kb.insertText(' '),
                ),
              ),
              Expanded(
                flex: 2,
                child: _ActionKeyButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: kb.moveCursorRight,
                ),
              ),
              Expanded(
                flex: 4,
                child: _ActionKeyButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  isAccent: true,
                  onTap: () {
                    onDonePressed?.call();
                    kb.submit();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolsLayout(BuildContext context, InAppKeyboardController kb) {
    const row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['-', '/', ':', ';', '(', ')', '\$', '&', '@', '"'];
    const row3 = ['.', ',', '?', '!', '\'', '%', '*', '+', '='];

    return Column(
      children: [
        Expanded(
          child: Row(
            children: row1
                .map((char) => Expanded(
                      child: _KeyButton(
                        label: char,
                        onTap: () => kb.insertText(char),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: row2
                .map((char) => Expanded(
                      child: _KeyButton(
                        label: char,
                        onTap: () => kb.insertText(char),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              ...row3.map((char) => Expanded(
                    flex: 2,
                    child: _KeyButton(
                      label: char,
                      onTap: () => kb.insertText(char),
                    ),
                  )),
              Expanded(
                flex: 3,
                child: _ActionKeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: kb.backspace,
                  onLongPress: kb.clear,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _ActionKeyButton(
                  label: 'ABC',
                  onTap: () => kb.setMode(VirtualKeyboardMode.letters),
                ),
              ),
              Expanded(
                flex: 2,
                child: _ActionKeyButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: kb.moveCursorLeft,
                ),
              ),
              Expanded(
                flex: 7,
                child: _KeyButton(
                  label: 'space',
                  isSpacebar: true,
                  onTap: () => kb.insertText(' '),
                ),
              ),
              Expanded(
                flex: 2,
                child: _ActionKeyButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: kb.moveCursorRight,
                ),
              ),
              Expanded(
                flex: 4,
                child: _ActionKeyButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  isAccent: true,
                  onTap: () {
                    onDonePressed?.call();
                    kb.submit();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadLayout(BuildContext context, InAppKeyboardController kb) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildNumpadKey('1', kb),
              _buildNumpadKey('2', kb),
              _buildNumpadKey('3', kb),
              Expanded(
                child: _ActionKeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: kb.backspace,
                  onLongPress: kb.clear,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              _buildNumpadKey('4', kb),
              _buildNumpadKey('5', kb),
              _buildNumpadKey('6', kb),
              Expanded(
                child: _ActionKeyButton(
                  label: 'ABC',
                  onTap: () => kb.setMode(VirtualKeyboardMode.letters),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              _buildNumpadKey('7', kb),
              _buildNumpadKey('8', kb),
              _buildNumpadKey('9', kb),
              Expanded(
                child: _ActionKeyButton(
                  label: 'Clear',
                  onTap: kb.clear,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              const Spacer(),
              _buildNumpadKey('0', kb),
              const Spacer(),
              Expanded(
                child: _ActionKeyButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  isAccent: true,
                  onTap: () {
                    onDonePressed?.call();
                    kb.submit();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadKey(String digit, InAppKeyboardController kb) {
    return Expanded(
      child: _KeyButton(
        label: digit,
        fontSize: 18,
        onTap: () => kb.insertText(digit),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSpacebar;
  final double fontSize;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.isSpacebar = false,
    this.fontSize = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.accentOrange.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderDark.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            child: Text(
              isSpacebar ? '' : label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;
  final Color? activeColor;
  final bool isAccent;

  const _ActionKeyButton({
    this.label,
    this.icon,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.activeColor,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAccent
        ? AppColors.cardSage
        : isActive
            ? (activeColor ?? AppColors.accentOrange).withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.04);

    final fgColor = isAccent
        ? AppColors.textOnLight
        : isActive
            ? (activeColor ?? AppColors.accentOrange)
            : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? (activeColor ?? AppColors.accentOrange)
                    : AppColors.borderDark,
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    size: 16,
                    color: fgColor,
                  ),
                if (icon != null && label != null) const SizedBox(width: 4),
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
