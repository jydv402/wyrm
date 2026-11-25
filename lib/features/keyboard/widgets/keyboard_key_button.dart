import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Single alphanumeric or space key button for virtual keyboards with tactile spring physics.
class KeyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSpacebar;
  final double fontSize;
  final DuskTone? tone;

  const KeyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isSpacebar = false,
    this.fontSize = 15.0,
    this.tone,
  });

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _isPressed = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final targetScale = (_isPressed && !disableMotion) ? 0.94 : 1.0;
    final motion = _isPressed
        ? const Motion.snappySpring(duration: Duration(milliseconds: 120))
        : const Motion.bouncySpring(
            duration: Duration(milliseconds: 320),
            extraBounce: 0.1,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: SingleMotionBuilder(
        value: targetScale,
        motion: disableMotion ? const Motion.none() : motion,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(8),
            splashColor: (widget.tone?.accent ?? AppColors.accentOrange)
                .withValues(alpha: 0.25),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: _buildKeyContainer(),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyContainer() {
    final accent = widget.tone?.accent ?? AppColors.accentOrange;
    final bgColor = _isPressed
        ? accent.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.08);
    final borderColor = _isPressed
        ? accent.withValues(alpha: 0.8)
        : (widget.tone != null
              ? widget.tone!.accent.withValues(alpha: 0.25)
              : AppColors.borderDark.withValues(alpha: 0.6));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Text(
        widget.isSpacebar ? '' : widget.label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Action key button (e.g. shift, backspace, mode switch, done) with support
/// for labels, icons, accent styling, active highlight state, and tactile spring physics.
class ActionKeyButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;
  final Color? activeColor;
  final bool isAccent;
  final DuskTone? tone;

  const ActionKeyButton({
    super.key,
    this.label,
    this.icon,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
    this.activeColor,
    this.isAccent = false,
    this.tone,
  });

  @override
  State<ActionKeyButton> createState() => _ActionKeyButtonState();
}

class _ActionKeyButtonState extends State<ActionKeyButton> {
  bool _isPressed = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final targetScale = (_isPressed && !disableMotion) ? 0.94 : 1.0;
    final motion = _isPressed
        ? const Motion.snappySpring(duration: Duration(milliseconds: 120))
        : const Motion.bouncySpring(
            duration: Duration(milliseconds: 320),
            extraBounce: 0.1,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: SingleMotionBuilder(
        value: targetScale,
        motion: disableMotion ? const Motion.none() : motion,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            onLongPress: widget.onLongPress,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(8),
            child: _buildActionContainer(),
          ),
        ),
      ),
    );
  }

  Color _resolveBgColor() {
    if (widget.isAccent) {
      return widget.tone?.fill ?? AppColors.cardSage;
    }
    final activeCol =
        widget.tone?.accent ?? widget.activeColor ?? AppColors.accentOrange;
    if (widget.isActive) {
      return activeCol.withValues(alpha: 0.3);
    }
    if (_isPressed) {
      return (widget.tone?.accent ?? AppColors.accentOrange).withValues(
        alpha: 0.18,
      );
    }
    return Colors.white.withValues(alpha: 0.04);
  }

  Color _resolveFgColor() {
    if (widget.isAccent) {
      return widget.tone?.ink ?? AppColors.textOnLight;
    }
    if (widget.isActive) {
      return widget.tone?.accent ??
          widget.activeColor ??
          AppColors.accentOrange;
    }
    if (_isPressed) {
      return widget.tone?.accent ?? AppColors.textPrimary;
    }
    return AppColors.textSecondary;
  }

  Color _resolveBorderColor() {
    if (widget.isAccent) {
      return widget.tone?.accent ?? AppColors.borderDark;
    }
    if (widget.isActive) {
      return widget.tone?.accent ??
          widget.activeColor ??
          AppColors.accentOrange;
    }
    if (_isPressed) {
      return (widget.tone?.accent ?? AppColors.accentOrange).withValues(
        alpha: 0.7,
      );
    }
    return AppColors.borderDark;
  }

  Widget _buildActionContainer() {
    final bgColor = _resolveBgColor();
    final borderColor = _resolveBorderColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final fgColor = _resolveFgColor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) Icon(widget.icon, size: 16, color: fgColor),
        if (widget.icon != null && widget.label != null)
          const SizedBox(width: 4),
        if (widget.label != null)
          Text(
            widget.label!,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
