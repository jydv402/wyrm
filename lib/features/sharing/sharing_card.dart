import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/sharing/sharing_notifier.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_browser_body.dart';
import 'package:wyrm_desk/features/sharing/widgets/sharing_small_body.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// Dusk Glass Cobalt Local File Sharing card displaying permission status,
/// quick password/QR controls, and the full folder browser across deck tiers.
class SharingCard extends ConsumerWidget {
  /// Invoked when the user picks a new size tier from the corner menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active layout tier for this card.
  final CardSize currentSize;

  /// Creates the dashboard [SharingCard].
  const SharingCard({
    super.key,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerMeta = ref.watch(
      sharingProvider.select(
        (s) => (hasPermission: s.hasPermission, count: s.entries.length),
      ),
    );
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.cobalt,
      icon: Icons.swap_horiz_rounded,
      title: 'Sharing',
      badge: DuskCountBadge(
        label: headerMeta.hasPermission && headerMeta.count > 0
            ? '${headerMeta.count}'
            : null,
        color: AppColors.cobaltAccent,
      ),
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      headerGap: isSmall ? 8.0 : 12.0,
      child: switch (currentSize) {
        CardSize.small => const SharingSmallBody(),
        CardSize.medium ||
        CardSize.fullscreen ||
        CardSize.nightstand => const SharingBrowserBody(),
      },
    );
  }
}
