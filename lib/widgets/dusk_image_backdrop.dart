import 'package:material_ui/material_ui.dart';

/// Full-bleed photographic card backdrop with a legibility gradient overlay.
///
/// The image is decoded at the larger on-screen dimension so `BoxFit.cover`
/// stays sharp without decoding the full multi-megabyte asset.
class DuskImageBackdrop extends StatelessWidget {
  /// Asset path of the backdrop image.
  final String assetPath;

  /// Gradient colours painted over the image, top to bottom.
  final List<Color> overlayColors;

  /// Whether to cross-fade when [assetPath] changes (time-of-day backdrops).
  final bool animate;

  const DuskImageBackdrop({
    super.key,
    required this.assetPath,
    this.overlayColors = const [
      Color(0x73000000), // black 45%
      Color(0x40000000), // black 25%
      Color(0xB3000000), // black 70%
    ],
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final backdrop = Stack(
      key: ValueKey<String>(assetPath),
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final longest = constraints.maxWidth >= constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;
            return Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: (longest * dpr).round(),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: overlayColors,
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );

    if (!animate) return backdrop;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1000),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: backdrop,
    );
  }
}
