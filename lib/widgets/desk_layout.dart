import 'package:flutter/material.dart';
import 'package:wyrm_desk/home/homepage.dart';
import 'calendar_card.dart';
import 'habits_card.dart';

export 'package:wyrm_desk/home/homepage.dart';

/// Legacy alias for [HomePage] to maintain backward compatibility and avoid redundancy.
typedef DeskLayout = HomePage;

/// Center column of the dashboard containing the top Habits card and bottom Calendar card.
///
/// Kept for convenience and backward compatibility.
class CenterBentoColumn extends StatelessWidget {
  final Widget? topChild;
  final Widget? bottomChild;
  final VoidCallback? onEditHabits;
  final VoidCallback? onEditCalendar;
  final double spacing;
  final int topFlex;
  final int bottomFlex;

  const CenterBentoColumn({
    super.key,
    this.topChild,
    this.bottomChild,
    this.onEditHabits,
    this.onEditCalendar,
    this.spacing = 10.0,
    this.topFlex = 4,
    this.bottomFlex = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: spacing,
      children: [
        Expanded(
          flex: topFlex,
          child: HabitsCard(onEdit: onEditHabits, child: topChild),
        ),
        Expanded(
          flex: bottomFlex,
          child: CalendarCard(onEdit: onEditCalendar, child: bottomChild),
        ),
      ],
    );
  }
}
