import 'package:battery_plus/battery_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/battery/battery_provider.dart';
import 'package:wyrm_desk/features/battery/battery_state.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Ambient Dusk Glass pill displaying current battery charge level and charging status.
class BatteryPill extends ConsumerWidget {
  const BatteryPill({super.key});

  /// Maps current battery status and percentage to the appropriate Material rounded icon.
  @visibleForTesting
  static IconData getBatteryIcon(BatteryInfo info) {
    if (info.isCharging) {
      return Icons.battery_charging_full_rounded;
    }
    if (info.level < 15) {
      return Icons.battery_alert_rounded;
    }
    if (info.level < 30) {
      return Icons.battery_2_bar_rounded;
    }
    if (info.level < 45) {
      return Icons.battery_3_bar_rounded;
    }
    if (info.level < 60) {
      return Icons.battery_4_bar_rounded;
    }
    if (info.level < 75) {
      return Icons.battery_5_bar_rounded;
    }
    if (info.level < 90) {
      return Icons.battery_6_bar_rounded;
    }
    return Icons.battery_full_rounded;
  }

  /// Resolves the foreground accent color for icon and text based on power state.
  @visibleForTesting
  static Color getBatteryColor(BatteryInfo info) {
    if (info.isCharging) {
      return AppColors.tealAccent;
    }
    if (info.isLowBattery) {
      return AppColors.accentRed;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryAsync = ref.watch(batteryInfoProvider);
    final info =
        batteryAsync.value ??
        const BatteryInfo(level: 100, state: BatteryState.unknown);

    final iconData = getBatteryIcon(info);
    final accentColor = getBatteryColor(info);
    final textColor = info.isCharging
        ? AppColors.tealAccent
        : (info.isLowBattery ? AppColors.accentRed : AppColors.textPrimary);

    final semanticsLabel = info.isCharging
        ? 'Battery charging, ${info.level} percent'
        : 'Battery ${info.level} percent';

    return Semantics(
      label: semanticsLabel,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.lineStrong, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(iconData, size: 19, color: accentColor),
            const SizedBox(width: 8),
            Text(
              '${info.level}%',
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
