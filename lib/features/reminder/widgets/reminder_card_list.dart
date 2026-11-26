import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_filter.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_empty_state.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_permission_banner.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_tile.dart';

/// Next-up banner plus a flat reminder list used by the small and medium tiers.
///
/// Both tiers always show every reminder, regardless of the fullscreen filter.
class ReminderCardList extends ConsumerWidget {
  /// Current reminder state snapshot.
  final RemindersState state;

  /// App settings supplying 24-hour format and card font size.
  final AppSettingsConfig settings;

  /// Current wall-clock instant used for countdowns.
  final DateTime now;

  /// Reminder with the earliest upcoming occurrence, if any.
  final ReminderItem? nextItem;

  /// Fire instant belonging to [nextItem], if any.
  final DateTime? nextFireAt;

  /// Whether to use the compact (small) spacing and tile layout.
  final bool compact;

  /// Whether tiles expose the delete button.
  final bool showDelete;

  /// Opens the editor for [item], or for a new reminder when `null`.
  final void Function(ReminderItem? item) onOpenEditor;

  const ReminderCardList({
    super.key,
    required this.state,
    required this.settings,
    required this.now,
    required this.nextItem,
    required this.nextFireAt,
    required this.compact,
    required this.showDelete,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPermissionBanner = !state.permissions.notificationsEnabled;
    final gap = compact ? 8.0 : 12.0;
    final items = state.copyWith(filter: ReminderFilter.all).filteredItems(now);

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          if (showPermissionBanner) const ReminderPermissionBanner(),
          Expanded(
            child: ReminderEmptyState(
              compact: compact,
              onAdd: () => onOpenEditor(null),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (showPermissionBanner) const ReminderPermissionBanner(),
        ReminderNextUpBanner(
          reminder: nextItem,
          fireAt: nextFireAt,
          now: now,
          is24Hour: settings.is24HourFormat,
          hasAnyReminders: true,
          compact: compact,
          onTap: nextItem != null ? () => onOpenEditor(nextItem) : null,
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(height: compact ? 6.0 : 8.0),
            itemBuilder: (context, index) {
              final item = items[index];
              return ReminderTile(
                key: ValueKey<String>('reminder_tile_${item.id}'),
                reminder: item,
                nextFireAt: state.nextFireAtFor(item, now),
                now: now,
                is24Hour: settings.is24HourFormat,
                titleFontSize: settings.cardFontSize,
                compact: compact,
                showDelete: showDelete,
                onTap: () => onOpenEditor(item),
                onToggle: (val) => ref
                    .read(remindersProvider.notifier)
                    .toggleReminder(item.id, val),
                onDelete: showDelete
                    ? () => ref
                          .read(remindersProvider.notifier)
                          .deleteReminder(item.id)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
