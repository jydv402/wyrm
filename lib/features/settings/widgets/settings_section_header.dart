import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Glacier icon badge with bold title and muted subtitle used atop each panel.
class SettingsSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SettingsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildIconBadge(),
        const SizedBox(width: 14),
        Expanded(child: _buildTitleBlock()),
      ],
    );
  }

  Widget _buildIconBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.glacierAccent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.glacierAccent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Icon(icon, color: AppColors.glacierAccent, size: 18),
    );
  }

  Widget _buildTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
          ),
        ),
      ],
    );
  }
}
