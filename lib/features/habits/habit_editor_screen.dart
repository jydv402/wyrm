import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/habits/habit_form_content.dart';
import 'package:wyrm_desk/features/habits/habit_model.dart';
import 'package:wyrm_desk/features/habits/habits_card.dart';
import 'package:wyrm_desk/features/habits/habits_state.dart';
import 'package:wyrm_desk/features/habits/widgets/universal_habit_card.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';

/// Full-screen two-pane habit editor screen.
class HabitEditorScreen extends ConsumerStatefulWidget {
  final HabitItem? habitToEdit;

  const HabitEditorScreen({super.key, this.habitToEdit});

  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends ConsumerState<HabitEditorScreen> {
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
      ref
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
      ref
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
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habitToEdit != null;

    return TwoPaneKeyboardScaffold(
      tone: AppColors.teal,
      title: isEditing ? 'Edit Habit' : 'New Habit',
      saveLabel: isEditing ? 'Save Changes' : 'Save Habit',
      saveButtonColor: AppColors.tealFill,
      saveTextColor: Colors.black,
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
        final title = _titleController.text.trim();
        final unit = _unitController.text.trim();
        final previewHabit = HabitItem(
          id: widget.habitToEdit?.id ?? 'preview',
          title: title.isEmpty ? 'Habit Preview' : title,
          type: _habitType,
          targetValue: _targetValue,
          unit: _habitType == HabitType.numeric && unit.isNotEmpty
              ? unit
              : null,
          iconName: _iconName,
          completions: widget.habitToEdit?.completions ?? const {},
          createdAt: widget.habitToEdit?.createdAt ?? DateTime.now(),
        );
        final today = DateTime.now();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 220),
            child: UniversalHabitCard(
              habit: previewHabit,
              today: today,
              weekStart: HabitsCard.getWeekStart(today, true),
              startWeekOnMonday: true,
            ),
          ),
        );
      },
    );
  }
}
