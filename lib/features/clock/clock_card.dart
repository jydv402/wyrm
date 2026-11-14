import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/features/clock/clock_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/clock/analog_clock.dart';
import 'package:wyrm_desk/widgets/bento_box.dart';
import 'package:wyrm_desk/features/clock/digital_clock_medium.dart';
import 'package:wyrm_desk/features/clock/digital_clock_small.dart';
import 'package:wyrm_desk/widgets/dusk_card_scaffold.dart';
import 'package:wyrm_desk/widgets/dusk_image_backdrop.dart';

/// Primary clock card container supporting Small, Medium, Fullscreen, and Nightstand sizing tiers.
class ClockContainer extends ConsumerWidget {
  final Widget? child;
  final ValueChanged<CardSize>? onSelectSize;
  final CardSize currentSize;

  const ClockContainer({
    super.key,
    this.child,
    this.onSelectSize,
    this.currentSize = CardSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNightstand = currentSize == CardSize.nightstand;
    final backgroundAsset = ref.watch(clockBackgroundAssetProvider);

    final Widget content;
    if (child != null) {
      content = child!;
    } else {
      switch (currentSize) {
        case CardSize.small:
          content = const DigitalClockSmall();
        case CardSize.medium:
          content = const DigitalClockMedium();
        case CardSize.fullscreen:
          content = const _ClockFullscreenView();
        case CardSize.nightstand:
          content = const _ClockFullscreenView(isNightstand: true);
      }
    }

    if (isNightstand) {
      return BentoBox(
        color: Colors.black,
        borderRadius: 0.0,
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              top: 0,
              right: 0,
              child:
                  cardSizeMenuButton(
                    currentSize: currentSize,
                    onSelectSize: onSelectSize ?? (_) {},
                    includeNightstand: true,
                  ) ??
                  const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return DuskCardScaffold(
      tone: AppColors.slate,
      icon: Icons.schedule_rounded,
      title: 'Clock',
      editButton: cardSizeMenuButton(
        currentSize: currentSize,
        onSelectSize: onSelectSize,
        includeNightstand: true,
      ),
      background: DuskImageBackdrop(
        assetPath: backgroundAsset,
        animate: true,
        overlayColors: const [
          Color(0x73000000), // black 45%
          Color(0x33000000), // black 20%
          Color(0xA6000000), // black 65%
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
      headerGap: 0.0,
      child: content,
    );
  }
}

/// Fullscreen companion view pairing a squircle analogue clock with the horizontal digital clock.
class _ClockFullscreenView extends StatelessWidget {
  final bool isNightstand;

  const _ClockFullscreenView({this.isNightstand = false});

  @override
  Widget build(BuildContext context) {
    final seamColor = isNightstand
        ? const Color(0xFFFF9500).withValues(alpha: 0.15)
        : AppColors.lineStrong;

    return Row(
      children: [
        // Left side: squircle analogue clock with Dieter Rams instrument aesthetic.
        Expanded(
          flex: 5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 24.0,
                horizontal: 24.0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnalogClock(size: 320, isNightstand: isNightstand),
              ),
            ),
          ),
        ),

        // Subtle vertical hardware separation seam.
        Container(width: 1.0, height: 220, color: seamColor),

        // Right side: horizontal digital clock layout.
        Expanded(
          flex: 6,
          child: Center(child: DigitalClockMedium(isNightstand: isNightstand)),
        ),
      ],
    );
  }
}
