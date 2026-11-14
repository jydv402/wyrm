import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/server/server_responses.dart';
import 'package:wyrm_desk/server/server_section.dart';

/// App settings' web remote surface: the settings REST route, the
/// `set_settings` WebSocket command, and the `settings` snapshot slice.
/// Lives beside [appSettingsProvider] in `lib/config/` because settings are
/// consumed by every card feature.
class SettingsServerSection implements ServerSection {
  final AppSettingsConfig Function() getSettings;
  final void Function(bool is24Hour) onSet24HourFormat;
  final void Function(double fontSize)? onSetCardFontSize;
  final void Function(bool startWeekOnMonday)? onSetStartWeekOnMonday;

  SettingsServerSection({
    required this.getSettings,
    required this.onSet24HourFormat,
    required this.onSetCardFontSize,
    required this.onSetStartWeekOnMonday,
  });

  @override
  void registerRoutes(Router router, ServerRuntime runtime) {
    router.post('/api/settings', (Request request) async {
      try {
        final data = await readJsonBody(request);
        if (_executeSetSettings(data)) {
          return jsonOk();
        }
      } catch (_) {}
      return jsonError('Invalid settings payload');
    });
  }

  @override
  bool handleMessage(Map<String, dynamic> data, ServerRuntime runtime) {
    if ((data['type'] as String?) != 'set_settings') return false;
    return _executeSetSettings(data);
  }

  @override
  Map<String, dynamic>? snapshot() {
    final settings = getSettings();
    return {
      'settings': {
        'is24HourFormat': settings.is24HourFormat,
        'cardFontSize': settings.cardFontSize,
        'startWeekOnMonday': settings.startWeekOnMonday,
      },
    };
  }

  /// Parses and applies general application settings (clock format, font size, week start).
  bool _executeSetSettings(Map<String, dynamic> data) {
    bool updated = false;
    if (data.containsKey('is24HourFormat')) {
      onSet24HourFormat(data['is24HourFormat'] as bool);
      updated = true;
    }
    if (data.containsKey('cardFontSize') && onSetCardFontSize != null) {
      onSetCardFontSize!((data['cardFontSize'] as num).toDouble());
      updated = true;
    }
    if (data.containsKey('startWeekOnMonday') &&
        onSetStartWeekOnMonday != null) {
      onSetStartWeekOnMonday!(data['startWeekOnMonday'] as bool);
      updated = true;
    }
    return updated;
  }
}
