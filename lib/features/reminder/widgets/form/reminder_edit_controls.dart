import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';

/// Edit-only controls: enabled switch and destructive delete action.
class ReminderEditControls extends StatelessWidget {
  /// Whether the reminder schedule is currently enabled.
  final bool isEnabled;

  /// Called when the enabled switch changes.
  final ValueChanged<bool> onEnabledChanged;

  /// Deletes the reminder, or `null` when deletion is unavailable.
  final VoidCallback? onDelete;

  const ReminderEditControls({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
