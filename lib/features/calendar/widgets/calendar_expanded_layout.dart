import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/features/calendar/calendar_state.dart';
import 'package:wyrm_desk/features/calendar/milestone_form_content.dart';
import 'package:wyrm_desk/features/calendar/widgets/calendar_month_view.dart';
import 'package:wyrm_desk/features/calendar/widgets/milestone_tile.dart';
import 'package:wyrm_desk/features/keyboard/two_pane_keyboard_scaffold.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Dual-pane expanded view for Medium and Fullscreen modes.
class CalendarExpandedLayout extends ConsumerWidget {
  final CalendarState state;
  final AppSettingsConfig settings;
  final VoidCallback? onAddMilestone;

  const CalendarExpandedLayout({
    super.key,
    required this.state,
    required this.settings,
    this.onAddMilestone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: CalendarMonthView(state: state, settings: settings),
        ),
        const SizedBox(width: 16),
        Container(width: 1.0, color: AppColors.lineStrong),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: _buildMilestonesPane(context, ref)),
      ],
    );
  }

  Widget _buildMilestonesPane(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMilestonesHeader(context, ref),
        const SizedBox(height: 12),
        Expanded(child: _buildMilestonesContent()),
      ],
    );
  }

  Widget _buildMilestonesHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Milestones & Countdowns',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildAddButton(context, ref),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
    return DuskGlassButton(
      onPressed: () {
        if (onAddMilestone != null) {
          onAddMilestone!();
        } else {
          openMilestoneTwoPaneEditor(context, ref);
        }
      },
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      icon: const Icon(
        Icons.add_rounded,
        size: 16,
        color: AppColors.textPrimary,
      ),
      label: const Text(
        'Add',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMilestonesContent() {
    if (state.milestones.isEmpty) {
      return const Center(
        child: Text(
          'No milestones recorded yet.\nTap Add to track an upcoming event.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: state.milestones.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          MilestoneTile(milestone: state.milestones[index]),
    );
  }
}

/// Opens the full-screen two-pane virtual keyboard milestone editor.
void openMilestoneTwoPaneEditor(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDate,
}) {
  final titleController = TextEditingController();
  var selectedTargetDate =
      initialDate ?? ref.read(calendarProvider).selectedDate;
  var isPinned = false;

  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => StatefulBuilder(
        builder: (context, setEditorState) => _buildMilestoneEditorScaffold(
          context,
          ref,
          titleController,
          selectedTargetDate,
          isPinned,
          (picked) => setEditorState(() => selectedTargetDate = picked),
          (val) => setEditorState(() => isPinned = val),
          () => setEditorState(() {}),
        ),
      ),
    ),
  );
}

Widget _buildMilestoneEditorScaffold(
  BuildContext context,
  WidgetRef ref,
  TextEditingController titleController,
  DateTime selectedDate,
  bool isPinned,
  ValueChanged<DateTime> onDateChanged,
  ValueChanged<bool> onPinnedChanged,
  VoidCallback onChanged,
) {
  void onSave() {
    final title = titleController.text.trim();
    if (title.isNotEmpty) {
      ref
          .read(calendarProvider.notifier)
          .addMilestone(title, selectedDate, isPinned: isPinned);
      Navigator.of(context).pop();
    }
  }

  return TwoPaneKeyboardScaffold(
    title: 'New Milestone',
    saveLabel: 'Save Milestone',
    saveButtonColor: AppColors.goldAccent,
    saveTextColor: Colors.black,
    onSave: onSave,
    formBuilder: (ctx, kb) => MilestoneFormContent(
      titleController: titleController,
      selectedDate: selectedDate,
      isPinned: isPinned,
      onDateChanged: onDateChanged,
      onPinnedChanged: onPinnedChanged,
      onChanged: onChanged,
    ),
    previewBuilder: (ctx) => MilestonePreviewCard(
      title: titleController.text,
      targetDate: selectedDate,
      isPinned: isPinned,
    ),
  );
}
