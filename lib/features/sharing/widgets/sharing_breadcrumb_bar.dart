import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Horizontal breadcrumb bar for navigating inside the active sharing root.
class SharingBreadcrumbBar extends StatelessWidget {
  /// Current relative path (`''` at root).
  final String currentRelativePath;

  /// Invoked when the user taps a breadcrumb target (`''` for root).
  final ValueChanged<String> onNavigate;

  /// Invoked when the user taps the Up button.
  final VoidCallback onNavigateUp;

  /// Creates a [SharingBreadcrumbBar].
  const SharingBreadcrumbBar({
    super.key,
    required this.currentRelativePath,
    required this.onNavigate,
    required this.onNavigateUp,
  });

  @override
  Widget build(BuildContext context) {
    final segments = currentRelativePath.isEmpty
        ? const <String>[]
        : currentRelativePath.split('/');

    return Row(
      children: [
        if (segments.isNotEmpty)
          IconButton(
            onPressed: onNavigateUp,
            icon: const Icon(
              Icons.arrow_upward_rounded,
              size: 17.0,
              color: AppColors.cobaltAccent,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30.0, minHeight: 30.0),
            tooltip: 'Parent folder',
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _BreadcrumbChip(
                  label: 'Shared',
                  isActive: segments.isEmpty,
                  onTap: () => onNavigate(''),
                ),
                for (var i = 0; i < segments.length; i++) ...[
                  const Padding(
                    padding: EdgeInsetsDirectional.symmetric(horizontal: 2.0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 15.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  _BreadcrumbChip(
                    label: segments[i],
                    isActive: i == segments.length - 1,
                    onTap: () {
                      final target = segments.take(i + 1).join('/');
                      onNavigate(target);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isActive ? null : onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 6.0,
          vertical: 4.0,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.cobaltAccent : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
