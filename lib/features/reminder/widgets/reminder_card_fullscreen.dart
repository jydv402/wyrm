import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/reminder/reminder_filter.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_empty_state.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_filter_pills.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_permission_status_card.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_tile.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Fullscreen (and nightstand) reminder layout: hero pane plus filterable list.
class ReminderCardFullscreen extends ConsumerWidget {
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

  /// Opens the editor for [item], or for a new reminder when `null`.
  final void Function(ReminderItem? item) onOpenEditor;

  const ReminderCardFullscreen({
    super.key,
    required this.state,
    required this.settings,
    required this.now,
    required this.nextItem,
    required this.nextFireAt,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = state.filteredItems(now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPane = _FullscreenLeftPane(
          state: state,
          settings: settings,
          now: now,
          nextItem: nextItem,
          nextFireAt: nextFireAt,
          onNewReminder: () => onOpenEditor(null),
          onOpenNext: nextItem != null ? () => onOpenEditor(nextItem) : null,
        );
        final rightPane = _FullscreenRightPane(
          state: state,
          settings: settings,
          now: now,
          filtered: filtered,
          onOpenEditor: onOpenEditor,
        );

        if (constraints.maxWidth < 680.0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              leftPane,
              Expanded(child: rightPane),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16.0,
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: leftPane,
              ),
            ),
            Container(width: 1.0, color: AppColors.lineStrong),
            Expanded(flex: 7, child: rightPane),
          ],
        );
      },
    );
  }
}

class _FullscreenLeftPane extends StatelessWidget {
  final RemindersState state;
  final AppSettingsConfig settings;
  final DateTime now;
  final ReminderItem? nextItem;
  final DateTime? nextFireAt;
  final VoidCallback onNewReminder;
  final VoidCallback? onOpenNext;

  const _FullscreenLeftPane({
    required this.state,
    required this.settings,
    required this.now,
    required this.nextItem,
    required this.nextFireAt,
    required this.onNewReminder,
    this.onOpenNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14.0,
      children: [
        ReminderNextUpBanner(
          reminder: nextItem,
          fireAt: nextFireAt,
          now: now,
          is24Hour: settings.is24HourFormat,
          hasAnyReminders: state.items.isNotEmpty,
          onTap: onOpenNext,
        ),
        ReminderFilterPills(selected: state.filter),
        ReminderPermissionStatusCard(permissions: state.permissions),
        DuskGlassButton(
          key: const ValueKey<String>('reminder_new_button'),
          onPressed: onNewReminder,
          isPrimary: true,
          primaryColor: AppColors.plumFill,
          primaryForegroundColor: AppColors.plumInk,
          height: 44.0,
          borderRadius: 16.0,
          icon: const Icon(
            Icons.alarm_add_rounded,
            size: 18.0,
            color: AppColors.plumInk,
          ),
          label: const Text(
            '+ New Reminder',
            style: TextStyle(
              color: AppColors.plumInk,
              fontSize: 14.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenRightPane extends ConsumerWidget {
  final RemindersState state;
  final AppSettingsConfig settings;
  final DateTime now;
  final List<ReminderItem> filtered;
  final void Function(ReminderItem? item) onOpenEditor;

  const _FullscreenRightPane({
    required this.state,
    required this.settings,
    required this.now,
    required this.filtered,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.0,
      children: [
        Text(
          '${state.filter.label} (${filtered.length})',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: state.items.isEmpty
              ? ReminderEmptyState(
                  compact: false,
                  onAdd: () => onOpenEditor(null),
                )
              : filtered.isEmpty
              ? _NoMatchState(filter: state.filter)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == filtered.length - 1 ? 0.0 : 8.0,
                      ),
                      child: ReminderTile(
                        key: ValueKey<String>('reminder_tile_${item.id}'),
                        reminder: item,
                        nextFireAt: state.nextFireAtFor(item, now),
                        now: now,
                        is24Hour: settings.is24HourFormat,
                        titleFontSize: settings.cardFontSize,
                        showDelete: true,
                        onTap: () => onOpenEditor(item),
                        onToggle: (val) => ref
                            .read(remindersProvider.notifier)
                            .toggleReminder(item.id, val),
                        onDelete: () => ref
                            .read(remindersProvider.notifier)
                            .deleteReminder(item.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NoMatchState extends ConsumerWidget {
  final ReminderFilter filter;

  const _NoMatchState({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10.0,
        children: [
          Text(
            'No ${filter.label.toLowerCase()} reminders',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          DuskGlassButton(
            onPressed: () => ref
                .read(remindersProvider.notifier)
                .setFilter(ReminderFilter.all),
            height: 36.0,
            label: const Text(
              'Show all',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
