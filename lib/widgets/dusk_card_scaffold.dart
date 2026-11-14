import 'package:material_ui/material_ui.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_card_header.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';

/// The one dashboard card frame: Dusk Glass surface, header row, and body.
///
/// Every card on the deck (Clock, Habits, Calendar, Tasks) is this frame plus
/// different content, so a card file only declares its tone, header labels,
/// actions, and body widget.
class DuskCardScaffold extends StatelessWidget {
  /// Destination tone supplying the panel gradient, border, glow, and accents.
  final DuskTone tone;

  /// Domain icon shown at the start of the header row.
  final IconData icon;

  /// Card title shown in the header row.
  final String title;

  /// Optional auxiliary badge placed beside the title (see [DuskCountBadge]).
  final Widget? badge;

  /// When non-null, the header shows the circular `+` add action.
  final VoidCallback? onAdd;

  /// Whether the add action uses the tone's filled treatment instead of glass.
  final bool filledAdd;

  /// App-supplied trailing control (the card-size menu button).
  final Widget? editButton;

  /// Optional full-bleed backdrop painted beneath the glass sheen.
  final Widget? background;

  /// Panel padding; defaults to the standard card padding.
  final EdgeInsetsGeometry? padding;

  /// Vertical gap between the header row and the body.
  final double headerGap;

  /// The card body, expanded to fill the remaining panel height.
  final Widget child;

  const DuskCardScaffold({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.child,
    this.badge,
    this.onAdd,
    this.filledAdd = true,
    this.editButton,
    this.background,
    this.padding,
    this.headerGap = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return DuskGlassPanel(
      tone: tone,
      borderRadius: 32.0,
      padding:
          padding ??
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      background: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuskCardHeader(
            icon: icon,
            title: title,
            accentColor: tone.accent,
            badge: badge,
            onAdd: onAdd,
            addColor: filledAdd ? tone.fill : null,
            addForegroundColor: filledAdd ? tone.ink : null,
            editButton: editButton,
          ),
          if (headerGap > 0) SizedBox(height: headerGap),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// "{done}/{total}" style pill shown beside a card title.
///
/// Passing a null [label] hides the badge, which is how empty cards avoid
/// rendering a meaningless "0/0".
class DuskCountBadge extends StatelessWidget {
  /// Badge text, or null to hide the badge entirely.
  final String? label;

  /// Accent colour of the owning card tone.
  final Color color;

  const DuskCountBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Centred "nothing here yet" state shared by the dashboard cards.
class DuskCardEmptyState extends StatelessWidget {
  /// Glyph shown inside the tinted circle.
  final IconData icon;

  /// Accent colour used for the circle fill, ring, and glyph.
  final Color accentColor;

  /// Primary line, e.g. "All caught up".
  final String title;

  /// Supporting line explaining the next action.
  final String subtitle;

  /// Optional call-to-action rendered under the subtitle.
  final Widget? action;

  /// Diameter of the tinted icon circle.
  final double circleSize;

  /// Border width of the tinted icon circle.
  final double circleBorderWidth;

  /// Gap between the icon circle and the title.
  final double iconGap;

  /// Whether to scale the whole state down when the card is short.
  final bool scaleDown;

  /// Extra space below the content, used to lift it above dead centre.
  final double bottomInset;

  const DuskCardEmptyState({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.action,
    this.circleSize = 68.0,
    this.circleBorderWidth = 1.5,
    this.iconGap = 16.0,
    this.scaleDown = false,
    this.bottomInset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.38),
              width: circleBorderWidth,
            ),
          ),
          child: Icon(icon, size: 34.0, color: accentColor),
        ),
        SizedBox(height: iconGap),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: 18.0), action!],
        if (bottomInset > 0) SizedBox(height: bottomInset),
      ],
    );

    return Center(
      child: scaleDown
          ? FittedBox(fit: BoxFit.scaleDown, child: content)
          : content,
    );
  }
}
