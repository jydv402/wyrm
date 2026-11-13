import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Compact vertical desk clock matching the screenshot reference.
class DigitalClockSmall extends ConsumerWidget {
  final bool isNightstand;

  const DigitalClockSmall({super.key, this.isNightstand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockTimeProvider).value ?? DateTime.now();
    final hours = ref.watch(clockHoursProvider);
    final minutes = ref.watch(clockMinutesProvider);
    final timeLeft = ref.watch(timeLeftTodayPartsProvider);

    // Greeting
    final String greeting;
    if (now.hour < 12) {
      greeting = 'Good morning';
    } else if (now.hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final dateStr = DateFormat('EEE, MMM d').format(now);

    final fontColor = isNightstand
        ? const Color(0xFFFF9500)
        : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Formatted Date (e.g. Thu, Sep 11)
        Text(
          dateStr,
          style: TextStyle(
            color: isNightstand
                ? const Color(0xFFFF9500).withValues(alpha: 0.7)
                : AppColors.textSecondary,
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),

        const SizedBox(height: 10),

        // Giant Stacked Digits
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hours,
                  style: GoogleFonts.barlowCondensed(
                    color: fontColor,
                    fontSize: 126,
                    fontWeight: FontWeight.w700,
                    height: 0.86,
                    letterSpacing: -2.0,
                  ),
                ),
                Text(
                  minutes,
                  style: GoogleFonts.barlowCondensed(
                    color: fontColor,
                    fontSize: 126,
                    fontWeight: FontWeight.w700,
                    height: 0.86,
                    letterSpacing: -2.0,
                  ),
                ),
                const SizedBox(height: 14),

                // Divider line
                Container(
                  width: 44,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: isNightstand
                        ? const Color(0xFFFF9500).withValues(alpha: 0.4)
                        : AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 14),

                // Greeting & Tagline
                Text(
                  greeting,
                  style: TextStyle(
                    color: fontColor,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Small steps, big progress.',
                  style: TextStyle(
                    color: isNightstand
                        ? const Color(0xFFFF9500).withValues(alpha: 0.5)
                        : AppColors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Sun Countdown Pill
        if (!isNightstand) ...[
          const SizedBox(height: 12),
          DuskGlassPill.sunCountdown(
            timeLeft: '${timeLeft.hours}h ${timeLeft.minutes}m',
            suffix: 'left today',
          ),
        ],
      ],
    );
  }
}
