import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/features/reminder/reminder_editor_screen.dart';
import 'package:wyrm_desk/features/reminder/reminder_state.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_tile.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/services/notifications/notification_gateway.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

export 'package:wyrm_desk/features/reminder/reminder_editor_screen.dart';

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
    final enabledCount = state.enabledItems.length;
    final nextItem = state.nextUpcoming(now);
    final nextFireAt = nextItem != null
        ? ReminderScheduler.nextFireAt(nextItem, now: now)
        : null;

    return DuskCardScaffold(
      tone: AppColors.plum,
      icon: Icons.notifications_active_rounded,
      title: 'Reminders',
      badge: DuskCountBadge(
        label: state.items.isEmpty ? null : '$enabledCount',
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
        CardSize.small => _SmallReminderBody(
          state: state,
          settings: settings,
          now: now,
          nextItem: nextItem,
          nextFireAt: nextFireAt,
          onOpenEditor: (item) => _openEditor(context, item),
        ),
        CardSize.medium => _MediumReminderBody(
          state: state,
          settings: settings,
          now: now,
          nextItem: nextItem,
          nextFireAt: nextFireAt,
          onOpenEditor: (item) => _openEditor(context, item),
        ),
        CardSize.fullscreen || CardSize.nightstand => _FullscreenReminderBody(
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

class _SmallReminderBody extends ConsumerWidget {
  final RemindersState state;
  final AppSettingsConfig settings;
  final DateTime now;
  final ReminderItem? nextItem;
  final DateTime? nextFireAt;
  final void Function(ReminderItem? item) onOpenEditor;

  const _SmallReminderBody({
    required this.state,
    required this.settings,
    required this.now,
    required this.nextItem,
    required this.nextFireAt,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPermBanner = !state.permissions.notificationsEnabled;
    final sortedAll = state
        .copyWith(filter: ReminderFilter.all)
        .filteredItems(now);

    if (sortedAll.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8.0,
        children: [
          if (showPermBanner) const _SlimPermissionBanner(),
          Expanded(
            child: _ReminderEmptyState(
              compact: true,
              onAdd: () => onOpenEditor(null),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        if (showPermBanner) const _SlimPermissionBanner(),
        ReminderNextUpBanner(
          reminder: nextItem,
          fireAt: nextFireAt,
          now: now,
          is24Hour: settings.is24HourFormat,
          hasAnyReminders: true,
          compact: true,
          onTap: nextItem != null ? () => onOpenEditor(nextItem) : null,
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: sortedAll.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6.0),
            itemBuilder: (context, index) {
              final item = sortedAll[index];
              return ReminderTile(
                key: ValueKey<String>('reminder_tile_${item.id}'),
                reminder: item,
                nextFireAt: state.nextFireAtFor(item, now),
                now: now,
                is24Hour: settings.is24HourFormat,
                titleFontSize: settings.cardFontSize,
                compact: true,
                showDelete: false,
                onTap: () => onOpenEditor(item),
                onToggle: (val) => ref
                    .read(remindersProvider.notifier)
                    .toggleReminder(item.id, val),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MediumReminderBody extends ConsumerWidget {
  final RemindersState state;
  final AppSettingsConfig settings;
  final DateTime now;
  final ReminderItem? nextItem;
  final DateTime? nextFireAt;
  final void Function(ReminderItem? item) onOpenEditor;

  const _MediumReminderBody({
    required this.state,
    required this.settings,
    required this.now,
    required this.nextItem,
    required this.nextFireAt,
    required this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPermBanner = !state.permissions.notificationsEnabled;
    final sortedAll = state
        .copyWith(filter: ReminderFilter.all)
        .filteredItems(now);

    if (sortedAll.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          if (showPermBanner) const _SlimPermissionBanner(),
          Expanded(
            child: _ReminderEmptyState(
              compact: false,
              onAdd: () => onOpenEditor(null),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12.0,
      children: [
        if (showPermBanner) const _SlimPermissionBanner(),
        ReminderNextUpBanner(
          reminder: nextItem,
          fireAt: nextFireAt,
          now: now,
          is24Hour: settings.is24HourFormat,
          hasAnyReminders: true,
          compact: false,
          onTap: nextItem != null ? () => onOpenEditor(nextItem) : null,
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: sortedAll.length,
            itemBuilder: (context, index) {
              final item = sortedAll[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == sortedAll.length - 1 ? 0.0 : 8.0,
                ),
                child: ReminderTile(
                  key: ValueKey<String>('reminder_tile_${item.id}'),
                  reminder: item,
                  nextFireAt: state.nextFireAtFor(item, now),
                  now: now,
                  is24Hour: settings.is24HourFormat,
                  titleFontSize: settings.cardFontSize,
                  compact: false,
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

class _FullscreenReminderBody extends ConsumerWidget {
  final RemindersState state;
  final AppSettingsConfig settings;
  final DateTime now;
  final ReminderItem? nextItem;
  final DateTime? nextFireAt;
  final void Function(ReminderItem? item) onOpenEditor;

  const _FullscreenReminderBody({
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
        final isWide = constraints.maxWidth >= 680.0;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              _FullscreenLeftPane(
                state: state,
                settings: settings,
                now: now,
                nextItem: nextItem,
                nextFireAt: nextFireAt,
                onNewReminder: () => onOpenEditor(null),
                onOpenNext: nextItem != null
                    ? () => onOpenEditor(nextItem)
                    : null,
              ),
              Expanded(
                child: _FullscreenRightPane(
                  state: state,
                  settings: settings,
                  now: now,
                  filtered: filtered,
                  onOpenEditor: onOpenEditor,
                ),
              ),
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
                child: _FullscreenLeftPane(
                  state: state,
                  settings: settings,
                  now: now,
                  nextItem: nextItem,
                  nextFireAt: nextFireAt,
                  onNewReminder: () => onOpenEditor(null),
                  onOpenNext: nextItem != null
                      ? () => onOpenEditor(nextItem)
                      : null,
                ),
              ),
            ),
            Container(width: 1.0, color: AppColors.lineStrong),
            Expanded(
              flex: 7,
              child: _FullscreenRightPane(
                state: state,
                settings: settings,
                now: now,
                filtered: filtered,
                onOpenEditor: onOpenEditor,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FullscreenLeftPane extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
          compact: false,
          onTap: onOpenNext,
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final filter in ReminderFilter.values)
              DuskGlassPill(
                key: ValueKey<String>('reminder_filter_${filter.name}'),
                onTap: () =>
                    ref.read(remindersProvider.notifier).setFilter(filter),
                tintColor: state.filter == filter
                    ? AppColors.plumAccent
                    : AppColors.textSecondary,
                height: 34.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: state.filter == filter
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: state.filter == filter
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        _PermissionStatusCard(permissions: state.permissions),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${state.filter.label} (${filtered.length})',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Expanded(
          child: state.items.isEmpty
              ? _ReminderEmptyState(
                  compact: false,
                  onAdd: () => onOpenEditor(null),
                )
              : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10.0,
                    children: [
                      Text(
                        'No ${state.filter.label.toLowerCase()} reminders',
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
                )
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
                        compact: false,
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

class _ReminderEmptyState extends StatelessWidget {
  final bool compact;
  final VoidCallback onAdd;

  const _ReminderEmptyState({required this.compact, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DuskCardEmptyState(
      icon: Icons.notifications_none_rounded,
      accentColor: AppColors.plumAccent,
      title: 'No reminders yet',
      subtitle: compact
          ? 'Tap below to schedule an alarm.'
          : 'Schedule one-time alarms or recurring daily nudges.',
      circleSize: compact ? 54.0 : 68.0,
      iconGap: compact ? 10.0 : 14.0,
      scaleDown: true,
      action: DuskGlassButton(
        onPressed: onAdd,
        isPrimary: true,
        primaryColor: AppColors.plumFill,
        primaryForegroundColor: AppColors.plumInk,
        height: compact ? 38.0 : 42.0,
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        icon: const Icon(
          Icons.add_rounded,
          size: 18.0,
          color: AppColors.plumInk,
        ),
        label: const Text(
          'Add reminder',
          style: TextStyle(
            color: AppColors.plumInk,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SlimPermissionBanner extends ConsumerWidget {
  const _SlimPermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref
            .read(remindersProvider.notifier)
            .requestNotificationsPermission(),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: AppColors.plumAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: AppColors.plumAccent.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: const Row(
            spacing: 8.0,
            children: [
              Icon(
                Icons.notifications_off_rounded,
                size: 14.0,
                color: AppColors.plumAccent,
              ),
              Expanded(
                child: Text(
                  'Notifications disabled — tap to allow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16.0,
                color: AppColors.plumAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStatusCard extends ConsumerWidget {
  final NotificationPermissionStatus permissions;

  const _PermissionStatusCard({required this.permissions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsEnabled = permissions.notificationsEnabled;
    final exactAlarmsAllowed = permissions.exactAlarmsAllowed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 10.0,
        children: [
          Icon(
            notificationsEnabled
                ? Icons.verified_user_rounded
                : Icons.notifications_off_rounded,
            size: 18.0,
            color: notificationsEnabled
                ? AppColors.plumAccent
                : AppColors.accentOrange,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.0,
              children: [
                Text(
                  notificationsEnabled
                      ? 'Notifications allowed'
                      : 'Notifications off',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  exactAlarmsAllowed
                      ? 'Precise timing active'
                      : 'Inexact background timing',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          if (!notificationsEnabled)
            DuskGlassButton(
              onPressed: () => ref
                  .read(remindersProvider.notifier)
                  .requestNotificationsPermission(),
              height: 32.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              label: const Text(
                'Enable',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
