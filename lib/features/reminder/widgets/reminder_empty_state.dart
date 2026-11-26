import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Empty-state placeholder shown when the reminder store has no items.
class ReminderEmptyState extends StatelessWidget {
  /// Whether the host card uses the compact (small) layout.
  final bool compact;

  /// Invoked when the user taps the "Add reminder" button.
  final VoidCallback onAdd;

  const ReminderEmptyState({
    super.key,
    required this.compact,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return DuskCardEmptyState(
      icon: Icons.notifications_none_rounded,
      accentColor: AppColors.plumAccent,
      title: 'No reminders yet',
      subtitle: compact
          ? 'Tap below to schedule an alarm.'
          : 'Schedule one-time alarms or recurring daily nudges.',
      circleSize: compact ? 54.0 : 68.0,
      iconGap: compact ? 10.0 : 14.0,
      scaleDown: true,
      action: DuskGlassButton(
        onPressed: onAdd,
        isPrimary: true,
        primaryColor: AppColors.plumFill,
        primaryForegroundColor: AppColors.plumInk,
        height: compact ? 38.0 : 42.0,
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        icon: const Icon(
          Icons.add_rounded,
          size: 18.0,
          color: AppColors.plumInk,
        ),
        label: const Text(
          'Add reminder',
          style: TextStyle(
            color: AppColors.plumInk,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
