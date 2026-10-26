import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';

/// Dusk Glass segmented control with an animated gliding thumb pill.
class DuskGlassSegmentedControl<T> extends StatelessWidget {
  final List<T> values;
  final T selectedValue;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onValueChanged;
  final Color? activeColor;
  final Color? activeTextColor;
  final double height;

  const DuskGlassSegmentedControl({
    super.key,
    required this.values,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onValueChanged,
    this.activeColor,
    this.activeTextColor,
    this.height = 42.0,
  });

  @override
  Widget build(BuildContext context) {
    final activeIndex = values.indexOf(selectedValue);
    final thumbColor = activeColor ?? AppColors.slate.fill;
    final thumbTextColor = activeTextColor ?? AppColors.slate.ink;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = values.length;
          final segmentWidth = constraints.maxWidth / count;

          return Stack(
            children: [
              // Gliding thumb pill
              if (activeIndex >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: activeIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: thumbColor.withValues(alpha: 0.4),
                          blurRadius: 10.0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

              // Segment text buttons
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: values.map((val) {
                  final isSelected = val == selectedValue;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onValueChanged(val),
                      borderRadius: BorderRadius.circular(height / 2),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? thumbTextColor : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                          child: Text(
                            labelBuilder(val),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
