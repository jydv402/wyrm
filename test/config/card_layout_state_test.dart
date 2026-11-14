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
      );

      final jsonMap = config.toJson();
      expect(jsonMap['clock'], 'medium');
      expect(jsonMap['habits'], 'fullscreen');
      expect(jsonMap['calendar'], 'small');
      expect(jsonMap['tasks'], 'medium');

      final restored = CardLayoutConfig.fromJson(jsonMap);
      expect(restored.clock, CardSize.medium);
      expect(restored.habits, CardSize.fullscreen);
      expect(restored.calendar, CardSize.small);
      expect(restored.tasks, CardSize.medium);
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
