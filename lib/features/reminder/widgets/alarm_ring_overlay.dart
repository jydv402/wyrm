import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/reminder/active_alarm_provider.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Root host overlaying [AlarmRingOverlay] over any active route when an alarm
/// is ringing (`activeAlarmProvider != null`).
class AlarmRingOverlayHost extends ConsumerWidget {
  final Widget child;

  const AlarmRingOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAlarm = ref.watch(activeAlarmProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (activeAlarm != null)
          Positioned.fill(child: AlarmRingOverlay(alarm: activeAlarm)),
      ],
    );
  }
}

/// Full-screen high-contrast Dusk Glass Plum alarm ringing surface.
class AlarmRingOverlay extends ConsumerStatefulWidget {
  final ActiveAlarmState alarm;

  const AlarmRingOverlay({super.key, required this.alarm});

  @override
  ConsumerState<AlarmRingOverlay> createState() => _AlarmRingOverlayState();
}

class _AlarmRingOverlayState extends ConsumerState<AlarmRingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled) {
      _entranceController.value = 1.0;
    } else if (_entranceController.status == AnimationStatus.dismissed) {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now =
        ref.watch(clockTimeProvider).value ?? ref.watch(clockProvider).now();
    final is24Hour = ref.watch(
      appSettingsProvider.select((settings) => settings.is24HourFormat),
    );
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final pulseHigh = !disableMotion && now.second.isEven;

    return PopScope(
      canPop: false,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        child: FadeTransition(
          opacity: _entranceController,
          child: Material(
            color: AppColors.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: _AmbientPlumBackdrop(
                      pulseHigh: pulseHigh,
                      disableAnimations: disableMotion,
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720.0;
                        if (isWide) {
                          return _WideAlarmLayout(
                            alarm: widget.alarm,
                            now: now,
                            is24Hour: is24Hour,
                            pulseHigh: pulseHigh,
                            disableAnimations: disableMotion,
                            onDismiss: _handleDismiss,
                            onSnooze: _handleSnooze,
                          );
                        }
                        return _NarrowAlarmLayout(
                          alarm: widget.alarm,
                          now: now,
                          is24Hour: is24Hour,
                          pulseHigh: pulseHigh,
                          disableAnimations: disableMotion,
                          onDismiss: _handleDismiss,
                          onSnooze: _handleSnooze,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDismiss() {
    ref.read(activeAlarmProvider.notifier).dismissActive();
  }

  void _handleSnooze() {
    ref.read(activeAlarmProvider.notifier).snoozeActive();
  }
}

class _WideAlarmLayout extends StatelessWidget {
  final ActiveAlarmState alarm;
  final DateTime now;
  final bool is24Hour;
  final bool pulseHigh;
  final bool disableAnimations;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const _WideAlarmLayout({
    required this.alarm,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24.0,
      children: [
        Expanded(
          flex: 42,
          child: _AlarmControlZone(
            alarm: alarm,
            now: now,
            is24Hour: is24Hour,
            pulseHigh: pulseHigh,
            disableAnimations: disableAnimations,
            onDismiss: onDismiss,
            onSnooze: onSnooze,
          ),
        ),
        Expanded(
          flex: 58,
          child: _AlarmReminderDisplayCard(
            alarm: alarm,
            is24Hour: is24Hour,
            titleFontSize: 48.0,
          ),
        ),
      ],
    );
  }
}

class _NarrowAlarmLayout extends StatelessWidget {
  final ActiveAlarmState alarm;
  final DateTime now;
  final bool is24Hour;
  final bool pulseHigh;
  final bool disableAnimations;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const _NarrowAlarmLayout({
    required this.alarm,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20.0,
        children: [
          _AlarmStatusHeader(
            now: now,
            is24Hour: is24Hour,
            pulseHigh: pulseHigh,
            disableAnimations: disableAnimations,
          ),
          _AlarmReminderDisplayCard(
            alarm: alarm,
            is24Hour: is24Hour,
            titleFontSize: 42.0,
          ),
          _AlarmButtonsColumn(
            snoozeMinutes: alarm.defaultSnooze.inMinutes,
            onDismiss: onDismiss,
            onSnooze: onSnooze,
          ),
        ],
      ),
    );
  }
}

class _AlarmControlZone extends StatelessWidget {
  final ActiveAlarmState alarm;
  final DateTime now;
  final bool is24Hour;
  final bool pulseHigh;
  final bool disableAnimations;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const _AlarmControlZone({
    required this.alarm,
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 20.0,
      children: [
        _AlarmStatusHeader(
          now: now,
          is24Hour: is24Hour,
          pulseHigh: pulseHigh,
          disableAnimations: disableAnimations,
        ),
        _AlarmButtonsColumn(
          snoozeMinutes: alarm.defaultSnooze.inMinutes,
          onDismiss: onDismiss,
          onSnooze: onSnooze,
        ),
      ],
    );
  }
}

class _AlarmStatusHeader extends StatelessWidget {
  final DateTime now;
  final bool is24Hour;
  final bool pulseHigh;
  final bool disableAnimations;

  const _AlarmStatusHeader({
    required this.now,
    required this.is24Hour,
    required this.pulseHigh,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    final period = is24Hour ? null : (now.hour >= 12 ? 'PM' : 'AM');
    final displayHour = is24Hour
        ? now.hour
        : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    final hourLabel = is24Hour
        ? displayHour.toString().padLeft(2, '0')
        : '$displayHour';
    final minuteLabel = now.minute.toString().padLeft(2, '0');
    final secondsLabel = now.second.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14.0,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: AppColors.plumAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(
              color: AppColors.plumAccent.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10.0,
            children: [
              AnimatedOpacity(
                opacity: pulseHigh ? 1.0 : 0.45,
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                child: Container(
                  width: 10.0,
                  height: 10.0,
                  decoration: const BoxDecoration(
                    color: AppColors.plumAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Text(
                'ALARM RINGING',
                style: TextStyle(
                  color: AppColors.plumAccent,
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 6.0,
            children: [
              Text(
                '$hourLabel:$minuteLabel',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 44.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ':$secondsLabel',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (period != null)
                Text(
                  period,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlarmButtonsColumn extends StatelessWidget {
  final int snoozeMinutes;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const _AlarmButtonsColumn({
    required this.snoozeMinutes,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14.0,
      children: [
        _AlarmActionButton(
          key: const ValueKey<String>('alarm_cancel_button'),
          minHeight: 96.0,
          backgroundColor: AppColors.plumFill,
          foregroundColor: AppColors.plumInk,
          glowColor: AppColors.plumFill.withValues(alpha: 0.45),
          icon: Icons.alarm_off_rounded,
          iconSize: 30.0,
          label: 'Cancel',
          fontSize: 24.0,
          fontWeight: FontWeight.w800,
          onPressed: onDismiss,
        ),
        _AlarmActionButton(
          key: const ValueKey<String>('alarm_snooze_button'),
          minHeight: 76.0,
          backgroundColor: AppColors.plumTop.withValues(alpha: 0.72),
          foregroundColor: AppColors.textPrimary,
          borderColor: AppColors.plumAccent.withValues(alpha: 0.42),
          icon: Icons.snooze_rounded,
          iconSize: 24.0,
          label: 'Snooze ${snoozeMinutes}m',
          fontSize: 19.0,
          fontWeight: FontWeight.w700,
          onPressed: onSnooze,
        ),
      ],
    );
  }
}

class _AlarmActionButton extends StatelessWidget {
  final double minHeight;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Color? glowColor;
  final IconData icon;
  final double iconSize;
  final String label;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback onPressed;

  const _AlarmActionButton({
    super.key,
    required this.minHeight,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.glowColor,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.fontSize,
    required this.fontWeight,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(24.0),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.5)
                  : null,
              boxShadow: glowColor != null
                  ? [
                      BoxShadow(
                        color: glowColor!,
                        blurRadius: 24.0,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12.0,
              children: [
                Icon(icon, size: iconSize, color: foregroundColor),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      letterSpacing: 0.2,
                    ),
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

class _AlarmReminderDisplayCard extends StatelessWidget {
  final ActiveAlarmState alarm;
  final bool is24Hour;
  final double titleFontSize;

  const _AlarmReminderDisplayCard({
    required this.alarm,
    required this.is24Hour,
    required this.titleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final reminder = alarm.reminder;
    final title = reminder.title.trim().isEmpty
        ? 'Reminder'
        : reminder.title.trim();
    final targetTimeLabel = formatReminderClockTime(
      alarm.firedAt,
      is24Hour: is24Hour,
    );
    final isSnoozed = reminder.snoozedUntil != null;

    return DuskGlassPanel(
      tone: AppColors.plum,
      borderRadius: 32.0,
      padding: const EdgeInsets.all(28.0),
      customBorder: Border.all(
        color: AppColors.plumAccent.withValues(alpha: 0.4),
        width: 1.4,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 20.0,
            children: [
              Wrap(
                spacing: 10.0,
                runSpacing: 8.0,
                children: [
                  DuskGlassPill(
                    tintColor: AppColors.plumAccent,
                    height: 32.0,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Text(
                      reminder.recurrence.label,
                      style: const TextStyle(
                        color: AppColors.plumAccent,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (reminder.recurrence == ReminderRecurrence.custom &&
                      reminder.customWeekdays.isNotEmpty)
                    DuskGlassPill(
                      tintColor: AppColors.textSecondary,
                      height: 32.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        formatReminderCustomWeekdays(reminder.customWeekdays),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isSnoozed)
                    const DuskGlassPill(
                      tintColor: AppColors.accentOrange,
                      height: 32.0,
                      padding: EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'Snoozed',
                        style: TextStyle(
                          color: AppColors.accentOrange,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (alarm.isPreview)
                    const DuskGlassPill(
                      tintColor: AppColors.glacierAccent,
                      height: 32.0,
                      padding: EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          color: AppColors.glacierAccent,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(
                    color: AppColors.plumAccent.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10.0,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 22.0,
                      color: AppColors.plumAccent,
                    ),
                    Text(
                      targetTimeLabel,
                      style: const TextStyle(
                        color: AppColors.plumAccent,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientPlumBackdrop extends StatelessWidget {
  final bool pulseHigh;
  final bool disableAnimations;

  const _AmbientPlumBackdrop({
    required this.pulseHigh,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _PlumBackdropPainter(intensity: 1.0)),
        AnimatedOpacity(
          opacity: pulseHigh ? 1.0 : 0.45,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 480),
          child: const CustomPaint(
            painter: _PlumBackdropPainter(intensity: 1.4, pulseOverlay: true),
          ),
        ),
      ],
    );
  }
}

class _PlumBackdropPainter extends CustomPainter {
  final double intensity;
  final bool pulseOverlay;

  const _PlumBackdropPainter({
    required this.intensity,
    this.pulseOverlay = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (!pulseOverlay) {
      canvas.drawRect(rect, Paint()..color = AppColors.background);
      final baseTopGlow = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.15,
          colors: [
            AppColors.plumTop.withValues(alpha: 0.72),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, baseTopGlow);
    }

    final accentGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.35, 0.25),
        radius: 0.95,
        colors: [
          AppColors.plumGlow.withValues(alpha: (0.28 * intensity).clamp(0, 1)),
          AppColors.plumAccent.withValues(
            alpha: (0.08 * intensity).clamp(0, 1),
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, accentGlow);
  }

  @override
  bool shouldRepaint(covariant _PlumBackdropPainter oldDelegate) =>
      oldDelegate.intensity != intensity ||
      oldDelegate.pulseOverlay != pulseOverlay;
}
