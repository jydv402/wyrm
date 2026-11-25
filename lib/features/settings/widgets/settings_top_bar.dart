import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Top navigation bar with back button, branded title, and close action.
class SettingsTopBar extends StatelessWidget {
  const SettingsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildBackButton(context),
        const SizedBox(width: 14),
        _buildBrandedIcon(),
        const SizedBox(width: 12),
        _buildTitleText(),
        const SizedBox(width: 12),
        _buildCloseButton(context),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return DuskGlassButton.icon(
      onPressed: () => context.pop(),
      size: 40.0,
      icon: const Icon(
        Icons.arrow_back_rounded,
        size: 20,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildBrandedIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.glacierAccent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.glacierAccent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: const Icon(
        Icons.settings_rounded,
        color: AppColors.glacierAccent,
        size: 19,
      ),
    );
  }

  Widget _buildTitleText() {
    return const Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 1),
          Text(
            'Ambient display, clock preferences, and companion server',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return DuskGlassButton.icon(
      onPressed: () => context.pop(),
      size: 40.0,
      icon: const Icon(
        Icons.close_rounded,
        size: 19,
        color: AppColors.textSecondary,
      ),
    );
  }
}
