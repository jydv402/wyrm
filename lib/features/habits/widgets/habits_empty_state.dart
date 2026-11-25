import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Empty state matching the reference screenshot: sprout circle, title, subtitle, "+ Add a habit".
class HabitsEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const HabitsEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DuskCardEmptyState(
      icon: Icons.spa_rounded,
      accentColor: AppColors.tealAccent,
      title: 'No habits for today',
      subtitle: 'Build the life you want, one habit at a time.',
      circleSize: 72.0,
      circleBorderWidth: 1.2,
      iconGap: 14.0,
      scaleDown: true,
      action: DuskGlassButton(
        onPressed: onAdd,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        icon: const Icon(
          Icons.add_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        label: const Text(
          'Add a habit',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
