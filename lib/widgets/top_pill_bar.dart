import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';

import 'bento_box.dart';

/// Top horizontal pill bar container matching the light cream banner in the design.
class TopPillBar extends StatelessWidget {
  final double height;
  final Widget? child;

  const TopPillBar({super.key, this.height = 54.0, this.child});

  @override
  Widget build(BuildContext context) {
    return BentoBox(
      height: height,
      color: AppColors.cardCream,
      borderRadius: height / 2,
      child: child,
    );
  }
}
