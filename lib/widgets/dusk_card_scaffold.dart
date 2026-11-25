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

  /// Optional auxiliary actions placed before the add button in the header.
  final List<Widget>? extraActions;

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
    this.extraActions,
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
        spacing: headerGap,
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
            extraActions: extraActions,
          ),
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

/// Centred Dusk Glass placeholder body for upcoming dashboard cards.
///
/// Adapts icon proportions to available height via [LayoutBuilder] and scrolls
/// if enlarged text requires extra vertical room, avoiding clipping or clamping.
class DuskComingSoonBody extends StatelessWidget {
  /// Domain icon rendered inside the tinted emblem circle.
  final IconData icon;

  /// Accent colour of the owning card tone.
  final Color accentColor;

  /// Concise capability headline shown beneath the emblem.
  final String headline;

  /// Short supporting description of what the card will do.
  final String description;

  /// Status tagline text shown inside the pill indicator.
  final String tagline;

  const DuskComingSoonBody({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.headline,
    required this.description,
    this.tagline = 'Coming soon',
  });

  @override
  Widget build(BuildContext context) {
    final boldText = MediaQuery.boldTextOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 240.0;
        final circleSize = isCompact ? 50.0 : 66.0;
        final iconSize = isCompact ? 24.0 : 32.0;

        return Center(
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ),
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 4.0,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.38),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(icon, size: iconSize, color: accentColor),
                    ),
                  ),
                  SizedBox(
                    height: isCompact ? 6.0 : 10.0,
                  ), // Originally was 10.0 / 14.0
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 10.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 5.0,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.upcoming_rounded,
                            size: 13.0,
                            color: accentColor,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            tagline,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11.5,
                              fontWeight: boldText
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: isCompact ? 4.0 : 8.0,
                  ), // Originally was 8.0 / 12.0
                  Text(
                    headline,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: isCompact ? 15.5 : 18.0,
                      fontWeight: boldText ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360.0),
                    child: Text(
                      description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isCompact ? 12.5 : 13.5,
                        fontWeight: boldText
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
