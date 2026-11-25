import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';

/// Live preview card for tasks.
class TaskPreviewCard extends StatelessWidget {
  final String title;
  final String priority;

  const TaskPreviewCard({
    super.key,
    required this.title,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.trim().isEmpty
        ? 'Write your task description...'
        : title.trim();
    final (String, Color)? badge = switch (priority.toLowerCase()) {
      'high' => ('HIGH', AppColors.priorityHigh),
      'medium' => ('MEDIUM', AppColors.priorityMedium),
      'low' => ('LOW', AppColors.priorityLow),
      _ => null,
    };

    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF452618), Color(0xFF22130C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.rustAccent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.rustAccent.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14.0,
        children: [
          Row(
            spacing: 6.0,
            children: [
              const Icon(
                Icons.check_box_outlined,
                size: 18,
                color: AppColors.rustAccent,
              ),
              const SizedBox(width: 2), // Originally was 8
              const Expanded(
                child: Text(
                  'PRIORITY PREVIEW',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badge.$2.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: badge.$2.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    badge.$1,
                    style: TextStyle(
                      color: badge.$2,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.rustAccent.withValues(alpha: 0.22),
                width: 1.0,
              ),
            ),
            child: Row(
              spacing: 12.0,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
