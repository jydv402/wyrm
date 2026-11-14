import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

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
          child: switch (effectiveController.mode) {
            VirtualKeyboardMode.letters => _LettersKeyboardLayout(
              kb: effectiveController,
              onDonePressed: onDonePressed,
            ),
            VirtualKeyboardMode.symbols => _SymbolsKeyboardLayout(
              kb: effectiveController,
              onDonePressed: onDonePressed,
            ),
            VirtualKeyboardMode.numpad => _NumpadKeyboardLayout(
              kb: effectiveController,
              onDonePressed: onDonePressed,
            ),
          },
        );
      },
    );
  }
}

/// QWERTY letter layout with shift, caps lock, cursor nudges, and Done.
class _LettersKeyboardLayout extends StatelessWidget {
  static const _row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  static const _row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;

  const _LettersKeyboardLayout({required this.kb, this.onDonePressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1
        Expanded(
          child: Row(
            children: _row1.map((char) {
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
              ..._row2.map((char) {
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
              ..._row3.map((char) {
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
        _KeyboardBottomBar(
          kb: kb,
          modeSwitchLabel: '?123',
          modeSwitchTarget: VirtualKeyboardMode.symbols,
          onDonePressed: onDonePressed,
        ),
      ],
    );
  }
}

/// Symbol and punctuation layout with backspace, cursor nudges, and Done.
class _SymbolsKeyboardLayout extends StatelessWidget {
  static const _row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  static const _row2 = ['-', '/', ':', ';', '(', ')', '\$', '&', '@', '"'];
  static const _row3 = ['.', ',', '?', '!', '\'', '%', '*', '+', '='];

  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;

  const _SymbolsKeyboardLayout({required this.kb, this.onDonePressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: _row1
                .map(
                  (char) => Expanded(
                    child: _KeyButton(
                      label: char,
                      onTap: () => kb.insertText(char),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: _row2
                .map(
                  (char) => Expanded(
                    child: _KeyButton(
                      label: char,
                      onTap: () => kb.insertText(char),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              ..._row3.map(
                (char) => Expanded(
                  flex: 2,
                  child: _KeyButton(
                    label: char,
                    onTap: () => kb.insertText(char),
                  ),
                ),
              ),
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
        _KeyboardBottomBar(
          kb: kb,
          modeSwitchLabel: 'ABC',
          modeSwitchTarget: VirtualKeyboardMode.letters,
          onDonePressed: onDonePressed,
        ),
      ],
    );
  }
}

/// Numeric keypad layout with backspace, mode switch, Clear, and Done.
class _NumpadKeyboardLayout extends StatelessWidget {
  final InAppKeyboardController kb;
  final VoidCallback? onDonePressed;

  const _NumpadKeyboardLayout({required this.kb, this.onDonePressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _NumpadKeyButton(digit: '1', kb: kb),
              _NumpadKeyButton(digit: '2', kb: kb),
              _NumpadKeyButton(digit: '3', kb: kb),
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
              _NumpadKeyButton(digit: '4', kb: kb),
              _NumpadKeyButton(digit: '5', kb: kb),
              _NumpadKeyButton(digit: '6', kb: kb),
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
              _NumpadKeyButton(digit: '7', kb: kb),
              _NumpadKeyButton(digit: '8', kb: kb),
              _NumpadKeyButton(digit: '9', kb: kb),
              Expanded(
                child: _ActionKeyButton(label: 'Clear', onTap: kb.clear),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Row(
            children: [
              const Spacer(),
              _NumpadKeyButton(digit: '0', kb: kb),
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
}

/// A single numpad digit key.
class _NumpadKeyButton extends StatelessWidget {
  final String digit;
  final InAppKeyboardController kb;

  const _NumpadKeyButton({required this.digit, required this.kb});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _KeyButton(
        label: digit,
        fontSize: 18,
        onTap: () => kb.insertText(digit),
      ),
    );
  }
}

/// Shared bottom row for the letter and symbol layouts: mode switch, cursor
/// nudges, spacebar, and Done.
class _KeyboardBottomBar extends StatelessWidget {
  final InAppKeyboardController kb;
  final String modeSwitchLabel;
  final VirtualKeyboardMode modeSwitchTarget;
  final VoidCallback? onDonePressed;

  const _KeyboardBottomBar({
    required this.kb,
    required this.modeSwitchLabel,
    required this.modeSwitchTarget,
    this.onDonePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _ActionKeyButton(
              label: modeSwitchLabel,
              onTap: () => kb.setMode(modeSwitchTarget),
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
                if (icon != null) Icon(icon, size: 16, color: fgColor),
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
