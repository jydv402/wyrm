import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_editor_screen.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_card_fullscreen.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_card_list.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// Dusk Glass Plum Reminders card displaying next-up countdowns and alarms
/// across [CardSize.small], [CardSize.medium], and [CardSize.fullscreen].
class ReminderCard extends ConsumerWidget {
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

  void _openEditor(BuildContext context, [ReminderItem? reminder]) {
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.reminderEditor, extra: reminder);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReminderEditorScreen(reminderToEdit: reminder),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(remindersProvider);
    final settings = ref.watch(appSettingsProvider);
    final now =
        ref.watch(clockTimeProvider).value ?? ref.watch(clockProvider).now();
    final isSmall = currentSize == CardSize.small;
    final nextItem = state.nextUpcoming(now);
    final nextFireAt = nextItem != null
        ? state.nextFireAtFor(nextItem, now)
        : null;

    return DuskCardScaffold(
      tone: AppColors.plum,
      icon: Icons.notifications_active_rounded,
      title: 'Reminders',
      badge: DuskCountBadge(
        label: state.items.isEmpty ? null : '${state.enabledItems.length}',
        color: AppColors.plumAccent,
      ),
      onAdd: () => _openEditor(context),
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
        CardSize.small => ReminderCardList(
          state: state,
          settings: settings,
          now: now,
          nextItem: nextItem,
          nextFireAt: nextFireAt,
          compact: true,
          showDelete: true,
          onOpenEditor: (item) => _openEditor(context, item),
        ),
        CardSize.medium => ReminderCardList(
          state: state,
          settings: settings,
          now: now,
          nextItem: nextItem,
          nextFireAt: nextFireAt,
          compact: false,
          showDelete: true,
          onOpenEditor: (item) => _openEditor(context, item),
        ),
        CardSize.fullscreen || CardSize.nightstand => ReminderCardFullscreen(
          state: state,
          settings: settings,
          now: now,
          nextItem: nextItem,
          nextFireAt: nextFireAt,
          onOpenEditor: (item) => _openEditor(context, item),
        ),
      },
    );
  }
}
