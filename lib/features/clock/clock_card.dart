import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/clock/clock_backdrop.dart';
import 'package:wyrm_desk/features/clock/clock_date_line.dart';
import 'package:wyrm_desk/features/clock/clock_face_digital_medium.dart';
import 'package:wyrm_desk/features/clock/clock_face_digital_small.dart';
import 'package:wyrm_desk/features/clock/clock_fullscreen_view.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/bento_box.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';

/// The clock card: one frame, four size tiers, one drifting day photograph.
///
/// Everything size-specific lives in the faces; this file only decides which
/// face a tier shows and how the tier is framed. The nightstand tier drops the
/// frame entirely for a pitch-black shelf display.
class ClockContainer extends ConsumerWidget {
  /// Body override; when null the face follows [currentSize].
  final Widget? child;

  /// Card-size menu handler; null hides the control.
  final ValueChanged<CardSize>? onSelectSize;

  /// Active size tier.
  final CardSize currentSize;

  const ClockContainer({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final face =
        child ??
        switch (currentSize) {
          CardSize.small => const DigitalClockSmall(),
          CardSize.medium => const DigitalClockMedium(),
          CardSize.fullscreen => const ClockFullscreenView(),
          CardSize.nightstand => const ClockFullscreenView(isNightstand: true),
        };

    final isNightstand = currentSize == CardSize.nightstand;

    // Every face repaints once a second. On its own layer that repaint stays
    // inside the face instead of re-rastering the photograph and its scrim,
    // which sit behind a clip on the same card.
    final content = RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClockDateLine(isNightstand: isNightstand),
          Expanded(child: face),
        ],
      ),
    );

    final menu = cardSizeMenuButton(
      currentSize: currentSize,
      onSelectSize: onSelectSize,
      includeNightstand: true,
    );

    if (currentSize == CardSize.nightstand) {
      return BentoBox(
        color: Colors.black,
        borderRadius: 0,
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned.fill(child: content),
            if (menu != null) Positioned(top: 0, right: 0, child: menu),
          ],
        ),
      );
    }

    return DuskCardScaffold(
      tone: AppColors.slate,
      icon: Icons.schedule_rounded,
      title: 'Clock',
      editButton: menu,
      background: ClockBackdrop(
        assetPath: ref.watch(clockBackgroundAssetProvider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      headerGap: 0,
      child: content,
    );
  }
}
