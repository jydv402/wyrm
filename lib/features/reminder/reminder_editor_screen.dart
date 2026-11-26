import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/core/notifications/reminder_model.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/features/reminder/reminder_form_content.dart';
import 'package:wyrm_desk/features/reminder/reminders_notifier.dart';
import 'package:wyrm_desk/services/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Full-screen two-pane virtual keyboard editor for creating and editing
/// reminders.
class ReminderEditorScreen extends ConsumerStatefulWidget {
  final ReminderItem? reminderToEdit;
  final String? reminderId;

  const ReminderEditorScreen({super.key, this.reminderToEdit, this.reminderId});

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  late final TextEditingController _titleController;
  ReminderItem? _editingItem;
  late int _hour;
  late int _minute;
  late DateTime _selectedDate;
  late ReminderRecurrence _recurrence;
  late List<int> _customWeekdays;
  late bool _isEnabled;
  int? _activeOffsetMinutes;
  bool _showTitleError = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _editingItem =
        widget.reminderToEdit ??
        _findById(ref.read(remindersProvider).items, widget.reminderId);

    final editing = _editingItem;
    if (editing != null) {
      _titleController = TextEditingController(text: editing.title);
      _hour = editing.scheduledAt.hour;
      _minute = editing.scheduledAt.minute;
      final todayStart = DateTime(now.year, now.month, now.day);
      final schedDay = DateTime(
        editing.scheduledAt.year,
        editing.scheduledAt.month,
        editing.scheduledAt.day,
      );
      _selectedDate = schedDay.isBefore(todayStart) ? todayStart : schedDay;
      _recurrence = editing.recurrence;
      _customWeekdays = editing.customWeekdays.isNotEmpty
          ? List<int>.from(editing.customWeekdays)
          : <int>[now.weekday];
      _isEnabled =
          editing.recurrence == ReminderRecurrence.once &&
              !editing.isEnabled &&
              !editing.scheduledAt.isAfter(now)
          ? true
          : editing.isEnabled;
    } else {
      final initialTarget = now.add(const Duration(minutes: 15));
      _titleController = TextEditingController();
      _hour = initialTarget.hour;
      _minute = initialTarget.minute;
      _selectedDate = DateTime(
        initialTarget.year,
        initialTarget.month,
        initialTarget.day,
      );
      _recurrence = ReminderRecurrence.once;
      _customWeekdays = <int>[now.weekday];
      _isEnabled = true;
      _activeOffsetMinutes = 15;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  static ReminderItem? _findById(List<ReminderItem> items, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _applyOffsetMinutes(int minutes) {
    final now = ref.read(clockProvider).now();
    final target = now.add(Duration(minutes: minutes));
    setState(() {
      _hour = target.hour;
      _minute = target.minute;
      _selectedDate = DateTime(target.year, target.month, target.day);
      _activeOffsetMinutes = minutes;
    });
  }

  void _toggleWeekday(int day) {
    setState(() {
      final next = _customWeekdays.toSet();
      if (!next.add(day)) {
        next.remove(day);
      }
      _customWeekdays = ReminderItem.normalizeWeekdays(next);
    });
  }

  void _popScreen() {
    if (!mounted) return;
    if (GoRouter.maybeOf(context) != null) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _saveReminder() async {
    if (_isSaving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      return;
    }
    if (_recurrence == ReminderRecurrence.custom && _customWeekdays.isEmpty) {
      return;
    }

    _isSaving = true;
    try {
      final now = ref.read(clockProvider).now();
      final resolved = resolveReminderTarget(
        now: now,
        hour: _hour,
        minute: _minute,
        selectedDate: _selectedDate,
        recurrence: _recurrence,
        customWeekdays: _customWeekdays,
      );
      final normalizedDays = _recurrence == ReminderRecurrence.custom
          ? ReminderItem.normalizeWeekdays(_customWeekdays)
          : const <int>[];

      final editing = _editingItem;
      final notifier = ref.read(remindersProvider.notifier);

      if (editing != null) {
        final scheduleChanged =
            editing.scheduledAt != resolved.scheduledAt ||
            editing.recurrence != _recurrence;
        await notifier.editReminder(
          editing.copyWith(
            title: title,
            scheduledAt: resolved.scheduledAt,
            recurrence: _recurrence,
            customWeekdays: normalizedDays,
            isEnabled: _isEnabled,
            clearSnoozedUntil: true,
            clearLastTriggeredAt: scheduleChanged,
          ),
        );
      } else {
        await notifier.addReminder(
          title: title,
          scheduledAt: resolved.scheduledAt,
          recurrence: _recurrence,
          customWeekdays: normalizedDays,
          isEnabled: true,
        );
      }

      _popScreen();
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _deleteReminder() async {
    if (_isSaving) return;
    final editing = _editingItem;
    if (editing == null) return;
    _isSaving = true;
    try {
      await ref.read(remindersProvider.notifier).deleteReminder(editing.id);
      _popScreen();
    } finally {
      _isSaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final is24Hour = ref.watch(
      appSettingsProvider.select((settings) => settings.is24HourFormat),
    );
    final now = ref.watch(clockProvider).now();
    final isEditing = _editingItem != null;

    return TwoPaneKeyboardScaffold(
      tone: AppColors.plum,
      title: isEditing ? 'Edit Reminder' : 'New Reminder',
      saveLabel: isEditing ? 'Save Changes' : 'Save Reminder',
      saveButtonColor: AppColors.plumFill,
      saveTextColor: AppColors.plumInk,
      onSave: _saveReminder,
      formBuilder: (context, keyboard) {
        return ReminderFormContent(
          titleController: _titleController,
          hour: _hour,
          minute: _minute,
          selectedDate: _selectedDate,
          now: now,
          is24Hour: is24Hour,
          recurrence: _recurrence,
          customWeekdays: _customWeekdays,
          isEnabled: _isEnabled,
          isEditing: isEditing,
          showTitleError: _showTitleError,
          activeOffsetMinutes: _activeOffsetMinutes,
          onHourChanged: (val) => setState(() {
            _hour = val;
            _activeOffsetMinutes = null;
          }),
          onMinuteChanged: (val) => setState(() {
            _minute = val;
            _activeOffsetMinutes = null;
          }),
          onDateChanged: (date) => setState(() {
            _selectedDate = date;
            _activeOffsetMinutes = null;
          }),
          onApplyOffsetMinutes: _applyOffsetMinutes,
          onRecurrenceChanged: (rec) => setState(() {
            _recurrence = rec;
            if (rec == ReminderRecurrence.custom && _customWeekdays.isEmpty) {
              _customWeekdays = <int>[now.weekday];
            }
          }),
          onToggleWeekday: _toggleWeekday,
          onEnabledChanged: (val) => setState(() => _isEnabled = val),
          onDelete: isEditing ? _deleteReminder : null,
          onChanged: () => setState(() {
            if (_showTitleError && _titleController.text.trim().isNotEmpty) {
              _showTitleError = false;
            }
          }),
          onSubmitted: (_) => _saveReminder(),
        );
      },
      previewBuilder: (context) {
        final resolved = resolveReminderTarget(
          now: now,
          hour: _hour,
          minute: _minute,
          selectedDate: _selectedDate,
          recurrence: _recurrence,
          customWeekdays: _customWeekdays,
        );
        return ReminderPreviewCard(
          title: _titleController.text,
          scheduledAt: resolved.scheduledAt,
          nextFireAt: resolved.nextFireAt,
          now: now,
          is24Hour: is24Hour,
          recurrence: _recurrence,
          customWeekdays: _customWeekdays,
          isEnabled: _isEnabled,
          autoWrappedToTomorrow: resolved.autoWrappedToTomorrow,
        );
      },
    );
  }
}
