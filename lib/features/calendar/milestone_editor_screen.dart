import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/calendar/milestone_form_content.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Full-screen two-pane virtual keyboard milestone editor screen.
class MilestoneEditorScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const MilestoneEditorScreen({super.key, this.initialDate});

  @override
  ConsumerState<MilestoneEditorScreen> createState() =>
      _MilestoneEditorScreenState();
}

class _MilestoneEditorScreenState extends ConsumerState<MilestoneEditorScreen> {
  late final TextEditingController _titleController;
  late DateTime _selectedDate;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _selectedDate =
        widget.initialDate ?? ref.read(calendarProvider).selectedDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveMilestone() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      ref
          .read(calendarProvider.notifier)
          .addMilestone(title, _selectedDate, isPinned: _isPinned);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TwoPaneKeyboardScaffold(
      tone: AppColors.gold,
      title: 'New Milestone',
      saveLabel: 'Save Milestone',
      saveButtonColor: AppColors.goldAccent,
      saveTextColor: Colors.black,
      onSave: _saveMilestone,
      formBuilder: (ctx, kb) => MilestoneFormContent(
        titleController: _titleController,
        selectedDate: _selectedDate,
        isPinned: _isPinned,
        onDateChanged: (picked) => setState(() => _selectedDate = picked),
        onPinnedChanged: (val) => setState(() => _isPinned = val),
        onChanged: () => setState(() {}),
      ),
      previewBuilder: (ctx) => MilestonePreviewCard(
        title: _titleController.text,
        targetDate: _selectedDate,
        isPinned: _isPinned,
      ),
    );
  }
}
