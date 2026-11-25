import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// Dusk Glass Reminders card (Phase 1 placeholder with live deck resizing).
///
/// Renders in the compact stacked square tier alongside [SharingCard] when
/// both are [CardSize.small], and expands independently to [CardSize.medium]
/// or [CardSize.fullscreen] via [onSelectSize].
class ReminderCard extends StatelessWidget {
  /// Invoked when the user picks a new size tier from the corner menu.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active layout tier for this card.
  final CardSize currentSize;

  /// Creates the dashboard [ReminderCard].
  const ReminderCard({
    super.key,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.plum,
      icon: Icons.notifications_active_rounded,
      title: 'Reminders',
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
        icon: Icons.alarm_add_rounded,
        accentColor: AppColors.plumAccent,
        headline: 'Timed & Recurring Alarms',
        description: isSmall ? 'One-time & interval alerts.' : 'Schedule one-time alarms, recurring hydration or stand-up nudges, and manage them from the web remote.',
      ),
    );
  }
}
