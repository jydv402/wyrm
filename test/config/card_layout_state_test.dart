import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';

void main() {
  group('CardLayoutConfig serialization', () {
    test('serializes to and deserializes from JSON accurately', () {
      const config = CardLayoutConfig(
        clock: CardSize.medium,
        habits: CardSize.fullscreen,
        calendar: CardSize.small,
        tasks: CardSize.medium,
        reminder: CardSize.medium,
        sharing: CardSize.fullscreen,
      );

      final jsonMap = config.toJson();
      expect(jsonMap['clock'], 'medium');
      expect(jsonMap['habits'], 'fullscreen');
      expect(jsonMap['calendar'], 'small');
      expect(jsonMap['tasks'], 'medium');
      expect(jsonMap['reminder'], 'medium');
      expect(jsonMap['sharing'], 'fullscreen');

      final restored = CardLayoutConfig.fromJson(jsonMap);
      expect(restored.clock, CardSize.medium);
      expect(restored.habits, CardSize.fullscreen);
      expect(restored.calendar, CardSize.small);
      expect(restored.tasks, CardSize.medium);
      expect(restored.reminder, CardSize.medium);
      expect(restored.sharing, CardSize.fullscreen);
    });

    test('defaults missing reminder and sharing keys to small', () {
      final restored = CardLayoutConfig.fromJson({
        'clock': 'small',
        'habits': 'medium',
        'calendar': 'small',
        'tasks': 'fullscreen',
      });

      expect(restored.clock, CardSize.small);
      expect(restored.habits, CardSize.medium);
      expect(restored.calendar, CardSize.small);
      expect(restored.tasks, CardSize.fullscreen);
      expect(restored.reminder, CardSize.small);
      expect(restored.sharing, CardSize.small);
    });

    test('supports sizeFor and withSize for reminder and sharing', () {
      const initial = CardLayoutConfig();
      expect(initial.sizeFor(DashboardCardType.reminder), CardSize.small);
      expect(initial.sizeFor(DashboardCardType.sharing), CardSize.small);

      final updated = initial
          .withSize(DashboardCardType.reminder, CardSize.medium)
          .withSize(DashboardCardType.sharing, CardSize.fullscreen);
      expect(updated.reminder, CardSize.medium);
      expect(updated.sharing, CardSize.fullscreen);
      expect(
        DashboardCardType.tryParse('REMINDER'),
        DashboardCardType.reminder,
      );
      expect(DashboardCardType.tryParse('sharing'), DashboardCardType.sharing);
    });

    test('handles nightstand serialization accurately', () {
      const config = CardLayoutConfig(clock: CardSize.nightstand);

      final json = config.toJson();
      expect(json['clock'], 'nightstand');

      final restored = CardLayoutConfig.fromJson(json);
      expect(restored.clock, CardSize.nightstand);
    });
  });
}
