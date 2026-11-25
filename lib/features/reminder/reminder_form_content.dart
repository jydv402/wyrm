import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/core/notifications/reminder_scheduler.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';
import 'package:wyrm_desk/features/reminder/widgets/reminder_next_up_banner.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';

/// Pure target-schedule resolution output for [ReminderFormContent] and
/// [ReminderPreviewCard].
typedef ResolvedReminderSchedule = ({
  DateTime scheduledAt,
  DateTime? nextFireAt,
  bool autoWrappedToTomorrow,
});

/// Resolves [scheduledAt] and [nextFireAt] for the current form inputs using an
/// explicit [now] timestamp.
///
/// For [ReminderRecurrence.once], if [selectedDate] is today (or earlier) and
/// the chosen clock time `hour:minute` is not strictly after [now], the target
/// automatically wraps to tomorrow and sets `autoWrappedToTomorrow = true`.
ResolvedReminderSchedule resolveReminderTarget({
  required DateTime now,
  required int hour,
  required int minute,
  required DateTime selectedDate,
  required ReminderRecurrence recurrence,
  required List<int> customWeekdays,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final pickedDay = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );

  if (recurrence == ReminderRecurrence.once) {
    if (!pickedDay.isAfter(todayStart)) {
      final todayCandidate = DateTime(
        todayStart.year,
        todayStart.month,
        todayStart.day,
        hour,
        minute,
      );
      if (!todayCandidate.isAfter(now)) {
        final tomorrowTarget = DateTime(
          todayStart.year,
          todayStart.month,
          todayStart.day + 1,
          hour,
          minute,
        );
        return (
          scheduledAt: tomorrowTarget,
          nextFireAt: tomorrowTarget,
          autoWrappedToTomorrow: true,
        );
      }
      return (
        scheduledAt: todayCandidate,
        nextFireAt: todayCandidate,
        autoWrappedToTomorrow: false,
      );
    }

    final futureTarget = DateTime(
      pickedDay.year,
      pickedDay.month,
      pickedDay.day,
      hour,
      minute,
    );
    return (
      scheduledAt: futureTarget,
      nextFireAt: futureTarget,
      autoWrappedToTomorrow: false,
    );
  }

  final anchor = DateTime(
    todayStart.year,
    todayStart.month,
    todayStart.day,
    hour,
    minute,
  );
  final previewItem = ReminderItem(
    id: 'preview',
    title: 'Preview',
    scheduledAt: anchor,
    recurrence: recurrence,
    customWeekdays: ReminderItem.normalizeWeekdays(customWeekdays),
    isEnabled: true,
    createdAt: now,
  );
  final nextFire = ReminderScheduler.nextFireAt(previewItem, now: now);
  return (
    scheduledAt: anchor,
    nextFireAt: nextFire,
    autoWrappedToTomorrow: false,
  );
}

/// Reusable Dusk Glass Plum form body for creating and editing reminders.
class ReminderFormContent extends StatelessWidget {
  final TextEditingController titleController;
  final int hour;
  final int minute;
  final DateTime selectedDate;
  final DateTime now;
  final bool is24Hour;
  final ReminderRecurrence recurrence;
  final List<int> customWeekdays;
  final bool isEnabled;
  final bool isEditing;
  final bool showTitleError;
  final int? activeOffsetMinutes;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int> onApplyOffsetMinutes;
  final ValueChanged<ReminderRecurrence> onRecurrenceChanged;
  final ValueChanged<int> onToggleWeekday;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onSubmitted;

  const ReminderFormContent({
    super.key,
    required this.titleController,
    required this.hour,
    required this.minute,
    required this.selectedDate,
    required this.now,
    required this.is24Hour,
    required this.recurrence,
    required this.customWeekdays,
    required this.isEnabled,
    required this.isEditing,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onDateChanged,
    required this.onApplyOffsetMinutes,
    required this.onRecurrenceChanged,
    required this.onToggleWeekday,
    required this.onEnabledChanged,
    this.showTitleError = false,
    this.activeOffsetMinutes,
    this.onDelete,
    this.onChanged,
    this.onSubmitted,
  });

  static const List<({int minutes, String label})> _offsetChips = [
    (minutes: 5, label: '+5m'),
    (minutes: 15, label: '+15m'),
    (minutes: 30, label: '+30m'),
    (minutes: 60, label: '+1h'),
  ];

  static const List<({int day, String short, String name})> _weekdayPills = [
    (day: DateTime.monday, short: 'M', name: 'Monday'),
    (day: DateTime.tuesday, short: 'T', name: 'Tuesday'),
    (day: DateTime.wednesday, short: 'W', name: 'Wednesday'),
    (day: DateTime.thursday, short: 'T', name: 'Thursday'),
    (day: DateTime.friday, short: 'F', name: 'Friday'),
    (day: DateTime.saturday, short: 'S', name: 'Saturday'),
    (day: DateTime.sunday, short: 'S', name: 'Sunday'),
  ];

  @override
  Widget build(BuildContext context) {
    final resolved = resolveReminderTarget(
      now: now,
      hour: hour,
      minute: minute,
      selectedDate: selectedDate,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16.0,
      children: [
        _buildTitleSection(),
        _buildQuickOffsetsSection(),
        _buildTimeSelectorSection(),
        if (recurrence == ReminderRecurrence.once)
          _buildDateSection(context, resolved),
        _buildRecurrenceSection(),
        if (recurrence == ReminderRecurrence.custom) _buildWeekdaysSection(),
        if (isEditing) _buildEditControlsSection(),
      ],
    );
  }

  Widget _buildTitleSection() {
    const baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14.0)),
      borderSide: BorderSide(color: AppColors.line, width: 1.0),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Reminder Title',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        InAppKeyboardTextField(
          controller: titleController,
          autofocus: !isEditing,
          cursorColor: AppColors.plumAccent,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.0),
          decoration: InputDecoration(
            hintText: 'e.g. Take meds, Stretch break, Laundry',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.well,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14.0)),
              borderSide: BorderSide(color: AppColors.plumAccent, width: 1.5),
            ),
          ),
          onChanged: (_) => onChanged?.call(),
          onSubmitted: onSubmitted,
        ),
        if (showTitleError)
          const Text(
            'Enter a title for this reminder.',
            style: TextStyle(
              color: AppColors.accentRed,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildQuickOffsetsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Quick Offset From Now',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final chip in _offsetChips)
              DuskGlassPill(
                key: ValueKey<String>('reminder_offset_${chip.minutes}'),
                onTap: () => onApplyOffsetMinutes(chip.minutes),
                tintColor: activeOffsetMinutes == chip.minutes
                    ? AppColors.plumAccent
                    : AppColors.textSecondary,
                height: 34.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    color: activeOffsetMinutes == chip.minutes
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSelectorSection() {
    final displayHour = is24Hour ? hour : (hour % 12 == 0 ? 12 : hour % 12);
    final hourLabel = displayHour.toString().padLeft(2, '0');
    final minuteLabel = minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Target Time',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TimeStepperPair(
              label: hourLabel,
              decKey: const ValueKey<String>('reminder_hour_dec'),
              incKey: const ValueKey<String>('reminder_hour_inc'),
              onDecrement: () => onHourChanged((hour + 23) % 24),
              onIncrement: () => onHourChanged((hour + 1) % 24),
            ),
            const Text(
              ':',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            _TimeStepperPair(
              label: minuteLabel,
              decKey: const ValueKey<String>('reminder_min_dec'),
              incKey: const ValueKey<String>('reminder_min_inc'),
              onDecrement: () => onMinuteChanged((minute + 59) % 60),
              onIncrement: () => onMinuteChanged((minute + 1) % 60),
            ),
            if (!is24Hour)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6.0,
                children: [
                  DuskGlassPill(
                    key: const ValueKey<String>('reminder_period_am'),
                    onTap: () {
                      if (isPm) onHourChanged(hour - 12);
                    },
                    tintColor: !isPm
                        ? AppColors.plumAccent
                        : AppColors.textSecondary,
                    height: 36.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'AM',
                      style: TextStyle(
                        color: !isPm
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DuskGlassPill(
                    key: const ValueKey<String>('reminder_period_pm'),
                    onTap: () {
                      if (!isPm) onHourChanged(hour + 12);
                    },
                    tintColor: isPm
                        ? AppColors.plumAccent
                        : AppColors.textSecondary,
                    height: 36.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'PM',
                      style: TextStyle(
                        color: isPm
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSection(
    BuildContext context,
    ResolvedReminderSchedule resolved,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final effectiveDay = DateTime(
      resolved.scheduledAt.year,
      resolved.scheduledAt.month,
      resolved.scheduledAt.day,
    );
    final isTodaySelected =
        !resolved.autoWrappedToTomorrow && effectiveDay == today;
    final isTomorrowSelected = effectiveDay == tomorrow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Target Date',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            DuskGlassPill(
              key: const ValueKey<String>('reminder_date_today'),
              onTap: () => onDateChanged(today),
              tintColor: isTodaySelected
                  ? AppColors.plumAccent
                  : AppColors.textSecondary,
              height: 34.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'Today',
                style: TextStyle(
                  color: isTodaySelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DuskGlassPill(
              key: const ValueKey<String>('reminder_date_tomorrow'),
              onTap: () => onDateChanged(tomorrow),
              tintColor: isTomorrowSelected
                  ? AppColors.plumAccent
                  : AppColors.textSecondary,
              height: 34.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'Tomorrow',
                style: TextStyle(
                  color: isTomorrowSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DuskGlassPill(
              key: const ValueKey<String>('reminder_date_pick'),
              onTap: () => _pickDate(context, today),
              tintColor: (!isTodaySelected && !isTomorrowSelected)
                  ? AppColors.plumAccent
                  : AppColors.textSecondary,
              height: 34.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              icon: const Icon(
                Icons.event_rounded,
                size: 14.0,
                color: AppColors.plumAccent,
              ),
              child: Text(
                (!isTodaySelected && !isTomorrowSelected)
                    ? formatReminderDayLabel(effectiveDay, now)
                    : 'Pick Date',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (resolved.autoWrappedToTomorrow)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.plumAccent.withValues(alpha: 0.14),
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
                  Icons.event_repeat_rounded,
                  size: 15.0,
                  color: AppColors.plumAccent,
                ),
                Expanded(
                  child: Text(
                    'Time passed today — auto-scheduled for Tomorrow',
                    style: TextStyle(
                      color: AppColors.plumAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime today) async {
    final initial = selectedDate.isBefore(today) ? today : selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.plumFill,
              onPrimary: AppColors.plumInk,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(DateTime(picked.year, picked.month, picked.day));
      onChanged?.call();
    }
  }

  Widget _buildRecurrenceSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final rec in ReminderRecurrence.values)
              DuskGlassPill(
                key: ValueKey<String>('reminder_recurrence_${rec.name}'),
                onTap: () => onRecurrenceChanged(rec),
                tintColor: recurrence == rec
                    ? AppColors.plumAccent
                    : AppColors.textSecondary,
                height: 34.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Text(
                  rec.label,
                  style: TextStyle(
                    color: recurrence == rec
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: recurrence == rec
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdaysSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8.0,
      children: [
        const Text(
          'Days of Week',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final pill in _weekdayPills)
              Semantics(
                label: pill.name,
                selected: customWeekdays.contains(pill.day),
                child: DuskGlassPill(
                  key: ValueKey<String>('reminder_weekday_${pill.day}'),
                  onTap: () => onToggleWeekday(pill.day),
                  tintColor: customWeekdays.contains(pill.day)
                      ? AppColors.plumAccent
                      : AppColors.textSecondary,
                  height: 36.0,
                  padding: const EdgeInsets.symmetric(horizontal: 13.0),
                  child: Text(
                    pill.short,
                    style: TextStyle(
                      color: customWeekdays.contains(pill.day)
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (customWeekdays.isEmpty)
          const Text(
            'Select at least one day of the week.',
            style: TextStyle(
              color: AppColors.accentRed,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildEditControlsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.0,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: AppColors.well,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: AppColors.line, width: 1.0),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Reminder Enabled',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeThumbColor: AppColors.plumAccent,
                activeTrackColor: AppColors.plumFill.withValues(alpha: 0.4),
                inactiveThumbColor: AppColors.textSecondary,
                inactiveTrackColor: AppColors.well,
                onChanged: onEnabledChanged,
              ),
            ],
          ),
        ),
        if (onDelete != null)
          DuskGlassButton(
            key: const ValueKey<String>('reminder_editor_delete_button'),
            onPressed: onDelete,
            height: 42.0,
            borderRadius: 14.0,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18.0,
              color: AppColors.accentRed,
            ),
            label: const Text(
              'Delete Reminder',
              style: TextStyle(
                color: AppColors.accentRed,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _TimeStepperPair extends StatelessWidget {
  final String label;
  final Key decKey;
  final Key incKey;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _TimeStepperPair({
    required this.label,
    required this.decKey,
    required this.incKey,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6.0,
        children: [
          DuskGlassButton.icon(
            key: decKey,
            onPressed: onDecrement,
            icon: const Icon(
              Icons.remove_rounded,
              size: 16.0,
              color: AppColors.textPrimary,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32.0),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          DuskGlassButton.icon(
            key: incKey,
            onPressed: onIncrement,
            icon: const Icon(
              Icons.add_rounded,
              size: 16.0,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-pane WYSIWYG live preview card for reminder schedules.
class ReminderPreviewCard extends StatelessWidget {
  final String title;
  final DateTime scheduledAt;
  final DateTime? nextFireAt;
  final DateTime now;
  final bool is24Hour;
  final ReminderRecurrence recurrence;
  final List<int> customWeekdays;
  final bool isEnabled;
  final bool autoWrappedToTomorrow;

  const ReminderPreviewCard({
    super.key,
    required this.title,
    required this.scheduledAt,
    required this.nextFireAt,
    required this.now,
    required this.is24Hour,
    required this.recurrence,
    required this.customWeekdays,
    this.isEnabled = true,
    this.autoWrappedToTomorrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.trim().isEmpty
        ? 'Write a reminder title...'
        : title.trim();
    final target = nextFireAt ?? scheduledAt;
    final formattedTime = formatReminderClockTime(target, is24Hour: is24Hour);
    final etaText = isEnabled
        ? formatReminderTriggerEta(target, now)
        : 'Paused';

    return Container(
      width: 340.0,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.plumTop, AppColors.plumBottom],
        ),
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: AppColors.plumAccent.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.plumGlow.withValues(alpha: 0.35),
            blurRadius: 24.0,
            spreadRadius: -4.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.0,
        children: [
          Row(
            spacing: 8.0,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                size: 18.0,
                color: AppColors.plumAccent,
              ),
              const Expanded(
                child: Text(
                  'REMINDER PREVIEW',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DuskGlassPill(
                tintColor: AppColors.plumAccent,
                height: 24.0,
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  recurrence.label,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: AppColors.plumAccent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6.0,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formattedTime,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26.0,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (recurrence == ReminderRecurrence.once) ...[
                      const SizedBox(width: 8.0),
                      DuskGlassPill(
                        tintColor: autoWrappedToTomorrow
                            ? AppColors.accentOrange
                            : AppColors.plumAccent,
                        height: 24.0,
                        padding: const EdgeInsets.symmetric(horizontal: 9.0),
                        child: Text(
                          formatReminderDayLabel(target, now),
                          style: TextStyle(
                            color: autoWrappedToTomorrow
                                ? AppColors.accentOrange
                                : AppColors.plumAccent,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  etaText,
                  style: const TextStyle(
                    color: AppColors.plumAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (recurrence == ReminderRecurrence.custom)
                  Text(
                    formatReminderCustomWeekdays(customWeekdays),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
