import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/clock/clock_provider.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'package:wyrm_desk/home/card_layout_state.dart';
import 'package:wyrm_desk/widgets/analog_clock.dart';
import 'package:wyrm_desk/widgets/bento_box.dart';
import 'package:wyrm_desk/widgets/card_edit_button.dart';
import 'package:wyrm_desk/widgets/digital_clock_medium.dart';
import 'package:wyrm_desk/widgets/digital_clock_small.dart';
import 'package:wyrm_desk/widgets/dusk_card_header.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

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
              child: CardEditButton(
                currentSize: currentSize,
                onSelectSize: onSelectSize ?? (_) {},
                showNightstandOption: true,
              ),
            ),
          ],
        ),
      );
    }

    return DuskGlassPanel(
      tone: AppColors.slate,
      borderRadius: 32.0,
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
      background: _ClockImageBackdrop(assetPath: backgroundAsset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuskCardHeader(
            icon: Icons.schedule_rounded,
            title: 'Clock',
            accentColor: AppColors.slate.accent,
            onSelectSize: onSelectSize,
            currentSize: currentSize,
            showNightstandOption: true,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Dynamic time-of-day photographic backdrop with smooth cross-fade animation
/// and dark gradient sheen for high-contrast typography readability.
class _ClockImageBackdrop extends StatelessWidget {
  final String assetPath;

  const _ClockImageBackdrop({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1000),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: Stack(
        key: ValueKey(assetPath),
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // High-contrast gradient overlay ensuring clock digits and labels remain legible
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ],
      ),
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
