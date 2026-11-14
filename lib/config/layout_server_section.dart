import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// Dashboard layout's web remote surface: card sizing and scroll-to-card
/// REST routes, the `set_layout` / `scroll_to_card` WebSocket commands, and
/// the `layout` snapshot slice. Lives beside [cardLayoutProvider] in
/// `lib/config/` because layout state is shared by every card feature.
class LayoutServerSection implements ServerSection {
  final CardLayoutConfig Function() getLayout;
  final void Function(DashboardCardType type, CardSize size) onSetCardSize;
  final void Function(DashboardCardType card)? onScrollToCard;

  LayoutServerSection({
    required this.getLayout,
    required this.onSetCardSize,
    required this.onScrollToCard,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.post('/api/layout', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeSetLayout(
          data['card'] as String?,
          data['size'] as String?,
        )) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid layout payload');
    });
    router.post('/api/scroll', (Request request) async {
      try {
        final data = await readJsonBody(request);
        final card = _executeScroll(data['card'] as String?);
        if (card != null) {
          return jsonOk({'card': card.name});
        }
      } catch (_) {}
      return jsonError('Invalid scroll payload');
    });
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    switch (data['type'] as String?) {
      case 'set_layout':
        _executeSetLayout(data['card'] as String?, data['size'] as String?);
        return true;
      case 'scroll_to_card':
        _executeScroll(data['card'] as String?);
        return true;
      default:
        return false;
    }
  }

  @override
  Map<String, dynamic>? snapshot() {
    return {'layout': getLayout().toJson()};
  }

  /// Applies card size and triggers auto-scroll to the adjusted card.
  bool _executeSetLayout(String? cardName, String? sizeName) {
    if (cardName == null || sizeName == null) return false;

    DashboardCardType? targetCard;
    for (final card in DashboardCardType.values) {
      if (card.name.toLowerCase() == cardName.toLowerCase()) {
        targetCard = card;
        break;
      }
    }

    CardSize? targetSize;
    for (final size in CardSize.values) {
      if (size.name.toLowerCase() == sizeName.toLowerCase()) {
        targetSize = size;
        break;
      }
    }

    if (targetCard != null && targetSize != null) {
      onSetCardSize(targetCard, targetSize);
      onScrollToCard?.call(targetCard);
      return true;
    }
    return false;
  }

  /// Triggers view scrolling to the specified dashboard card.
  DashboardCardType? _executeScroll(String? cardName) {
    final card = DashboardCardType.tryParse(cardName);
    if (card != null) {
      onScrollToCard?.call(card);
    }
    return card;
  }
}
