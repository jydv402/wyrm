import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// Dusk Glass Local File Sharing card (Phase 1 placeholder with live deck resizing).
///
/// Renders in the compact stacked square tier alongside [ReminderCard] when
/// both are [CardSize.small], and expands independently to [CardSize.medium]
/// or [CardSize.fullscreen] via [onSelectSize].
class SharingCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.cobalt,
      icon: Icons.swap_horiz_rounded,
      title: 'Sharing',
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      headerGap: isSmall ? 6.0 : 12.0,
      child: DuskComingSoonBody(
        icon: Icons.folder_shared_rounded,
        accentColor: AppColors.cobaltAccent,
        headline: 'LAN File Sharing',
        description: isSmall ? 'Send, browse & relay over Wi-Fi.' : 'Upload files to the tablet, download tablet files from the web remote, or share between devices via the tablet server.',
      ),
    );
  }
}
