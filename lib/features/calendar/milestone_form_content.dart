import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/features/calendar/widgets/form/milestone_date_selector.dart';
import 'package:wyrm_desk/features/keyboard/in_app_keyboard_text_field.dart';
import 'package:wyrm_desk/theme/theme.dart';

export 'package:wyrm_desk/features/calendar/widgets/form/milestone_date_selector.dart';
export 'package:wyrm_desk/features/calendar/widgets/form/milestone_preview_tile.dart';

/// Reusable form content for creating and editing calendar milestones in Dusk Glass style.
class MilestoneFormContent extends StatelessWidget {
  final TextEditingController titleController;
  final DateTime selectedDate;
  final bool isPinned;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<bool> onPinnedChanged;
  final VoidCallback? onChanged;

  const MilestoneFormContent({
    super.key,
    required this.titleController,
    required this.selectedDate,
    required this.isPinned,
    required this.onDateChanged,
    required this.onPinnedChanged,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18.0,
      children: [
        _buildNameField(),
        MilestoneDateSelector(
          selectedDate: selectedDate,
          onDateChanged: onDateChanged,
          onChanged: onChanged,
        ),
        _buildPinTile(),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8.0,
      children: [
        const Text(
          'Milestone Name',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        _buildTextField(),
      ],
    );
  }

  Widget _buildTextField() {
    return InAppKeyboardTextField(
      controller: titleController,
      autofocus: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: _inputDecoration(),
      onChanged: (_) => onChanged?.call(),
    );
  }

  InputDecoration _inputDecoration() {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AppColors.line, width: 1.0),
    );
    return const InputDecoration(
      hintText: 'e.g. Project Launch, Anniversary, Vacation',
      hintStyle: TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.well,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.goldAccent, width: 1.5),
      ),
    );
  }

  Widget _buildPinTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: Row(
        spacing: 12.0,
        children: [
          const Icon(
            Icons.push_pin_rounded,
            size: 18,
            color: AppColors.goldAccent,
          ),
          Expanded(child: _buildPinText()),
          _buildPinSwitch(),
        ],
      ),
    );
  }

  static Widget _buildPinText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pin to Countdown Pill',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Text(
          'Highlights prominently at the top of the calendar card',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPinSwitch() {
    return Switch.adaptive(
      value: isPinned,
      activeThumbColor: AppColors.goldFill,
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.well,
      onChanged: (val) {
        onPinnedChanged(val);
        onChanged?.call();
      },
    );
  }
}
