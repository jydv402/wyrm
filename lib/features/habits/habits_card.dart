import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/habits/habit_form_content.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_carousel_view.dart';
import 'package:wyrm_desk/features/habits/widgets/habits_expanded_grid.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// Dusk Glass Habits card with teal gradient, empty state matching the reference,
/// and interactive 7-day completion matrices.
class HabitsCard extends ConsumerWidget {
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;

  const HabitsCard({
    super.key,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  /// Resolves midnight of the week containing [referenceDate].
  static DateTime getWeekStart(DateTime referenceDate, bool startWeekOnMonday) {
    final ref = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final daysToSubtract = startWeekOnMonday
        ? ref.weekday - 1
        : ref.weekday % 7;
    return ref.subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsState = ref.watch(habitsProvider);
    final settings = ref.watch(appSettingsProvider);
    final isSmall = currentSize == CardSize.small;

    return DuskCardScaffold(
      tone: AppColors.teal,
      icon: Icons.eco_rounded,
      title: 'Habits',
      badge: DuskCountBadge(
        label: habitsState.habits.isEmpty
            ? null
            : '${habitsState.completedTodayCount()}/${habitsState.habits.length}',
        color: AppColors.tealAccent,
      ),
      onAdd: () => openHabitTwoPaneEditor(context, ref),
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16.0 : 20.0,
        vertical: 14.0,
      ),
      headerGap: 12.0,
      child: isSmall
          ? HabitsCarouselView(
              state: habitsState,
              settings: settings,
              onAdd: () => openHabitTwoPaneEditor(context, ref),
            )
          : HabitsExpandedGrid(
              state: habitsState,
              settings: settings,
              isFullscreen: currentSize == CardSize.fullscreen,
              onAdd: () => openHabitTwoPaneEditor(context, ref),
              onEdit: (habit) =>
                  openHabitTwoPaneEditor(context, ref, habitToEdit: habit),
            ),
    );
  }
}

/// Opens the full-screen two-pane virtual keyboard habit editor.
void openHabitTwoPaneEditor(
  BuildContext context,
  WidgetRef ref, {
  HabitItem? habitToEdit,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) =>
          _HabitEditorSheet(ref: ref, habitToEdit: habitToEdit),
    ),
  );
}

class _HabitEditorSheet extends StatefulWidget {
  final WidgetRef ref;
  final HabitItem? habitToEdit;

  const _HabitEditorSheet({required this.ref, this.habitToEdit});

  @override
  State<_HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<_HabitEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _unitController;
  late HabitType _habitType;
  late int _targetValue;
  late String _iconName;

  @override
  void initState() {
    super.initState();
    final habit = widget.habitToEdit;
    _titleController = TextEditingController(text: habit?.title ?? '');
    _unitController = TextEditingController(text: habit?.unit ?? '');
    _habitType = habit?.type ?? HabitType.binary;
    _targetValue =
        habit?.targetValue ?? (_habitType == HabitType.numeric ? 8 : 1);
    _iconName = habit?.iconName ?? 'bolt';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    final title = _titleController.text.trim();
    final unit = _unitController.text.trim();
    if (title.isEmpty) return;

    final habit = widget.habitToEdit;
    final resolvedUnit = _habitType == HabitType.numeric && unit.isNotEmpty
        ? unit
        : null;

    if (habit != null) {
      widget.ref
          .read(habitsProvider.notifier)
          .editHabit(
            habit.copyWith(
              title: title,
              type: _habitType,
              targetValue: _targetValue,
              unit: resolvedUnit,
              iconName: _iconName,
            ),
          );
    } else {
      widget.ref
          .read(habitsProvider.notifier)
          .addHabit(
            HabitItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              type: _habitType,
              targetValue: _targetValue,
              unit: resolvedUnit,
              iconName: _iconName,
              createdAt: DateTime.now(),
            ),
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habitToEdit != null;

    return TwoPaneKeyboardScaffold(
      title: isEditing ? 'Edit Habit' : 'New Habit',
      saveLabel: isEditing ? 'Save Changes' : 'Save Habit',
      saveButtonColor: AppColors.tealFill,
      saveTextColor: Colors.white,
      onSave: _saveHabit,
      formBuilder: (context, keyboard) {
        return HabitFormContent(
          titleController: _titleController,
          unitController: _unitController,
          habitType: _habitType,
          targetCount: _targetValue,
          selectedIcon: _iconName,
          onTypeChanged: (type) => setState(() => _habitType = type),
          onTargetCountChanged: (val) => setState(() => _targetValue = val),
          onIconChanged: (icon) => setState(() => _iconName = icon),
          onChanged: () => setState(() {}),
          isEditing: isEditing,
        );
      },
      previewBuilder: (context) {
        return HabitPreviewTile(
          title: _titleController.text,
          type: _habitType,
          targetCount: _targetValue,
          unit: _unitController.text.trim().isEmpty
              ? null
              : _unitController.text.trim(),
          iconName: _iconName,
        );
      },
    );
  }
}
