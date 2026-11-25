import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Well-tinted setting row that stacks label and control on narrow widths.
class SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 460;
          return isCompact ? _buildCompact() : _buildWide();
        },
      ),
    );
  }

  Widget _buildCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.glacierAccent),
            const SizedBox(width: 12),
            Expanded(child: _buildTextContent()),
          ],
        ),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: trailing),
      ],
    );
  }

  Widget _buildWide() {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.glacierAccent),
        const SizedBox(width: 14),
        Expanded(child: _buildTextContent()),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
