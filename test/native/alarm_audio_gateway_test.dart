import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyrm_desk/native/alarm_audio_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('MethodChannelAlarmAudioGateway', () {
    const gateway = MethodChannelAlarmAudioGateway();
    late List<MethodCall> recordedCalls;

    setUp(() {
      recordedCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        MethodChannelAlarmAudioGateway.channel,
        null,
      );
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(
        MethodChannelAlarmAudioGateway.channel,
        null,
      );
    });

    test('invokes expected methods and arguments on wyrm_desk/alarm', () async {
      messenger.setMockMethodCallHandler(
        MethodChannelAlarmAudioGateway.channel,
        (call) async {
          recordedCalls.add(call);
          if (call.method == 'startAlarmChime') {
            return true;
          }
          return null;
        },
      );

      await gateway.startChime();
      await gateway.setWakeScreen(true);
      await gateway.stopChime();
      await gateway.setWakeScreen(false);

      expect(recordedCalls.map((call) => call.method).toList(), [
        'startAlarmChime',
        'setWakeScreen',
        'stopAlarmChime',
        'setWakeScreen',
      ]);
      expect(recordedCalls[0].arguments, isNull);
      expect(recordedCalls[1].arguments, isTrue);
      expect(recordedCalls[2].arguments, isNull);
      expect(recordedCalls[3].arguments, isFalse);
    });

    test(
      'completes cleanly when startAlarmChime reports false (no ringtone)',
      () async {
        messenger.setMockMethodCallHandler(
          MethodChannelAlarmAudioGateway.channel,
          (call) async {
            recordedCalls.add(call);
            if (call.method == 'startAlarmChime') {
              return false;
            }
            return null;
          },
        );

        await expectLater(gateway.startChime(), completes);
        expect(recordedCalls, hasLength(1));
        expect(recordedCalls.single.method, 'startAlarmChime');
      },
    );

    test(
      'handles MissingPluginException gracefully when no native handler exists',
      () async {
        await expectLater(gateway.startChime(), completes);
        await expectLater(gateway.setWakeScreen(true), completes);
        await expectLater(gateway.stopChime(), completes);
        await expectLater(gateway.setWakeScreen(false), completes);
      },
    );

    test('handles PlatformException gracefully without rethrowing', () async {
      messenger.setMockMethodCallHandler(
        MethodChannelAlarmAudioGateway.channel,
        (call) async {
          throw PlatformException(
            code: 'ALARM_FAILED',
            message: 'Simulated failure',
          );
        },
      );

      await expectLater(gateway.startChime(), completes);
      await expectLater(gateway.setWakeScreen(true), completes);
      await expectLater(gateway.stopChime(), completes);
    });
  });

  group('FakeAlarmAudioGateway', () {
    test(
      'records isPlaying, wakeScreenEnabled, startCount, and stopCount',
      () async {
        final fake = FakeAlarmAudioGateway();

        expect(fake.isPlaying, isFalse);
        expect(fake.wakeScreenEnabled, isFalse);
        expect(fake.startCount, 0);
        expect(fake.stopCount, 0);

        await fake.setWakeScreen(true);
        await fake.startChime();

        expect(fake.isPlaying, isTrue);
        expect(fake.wakeScreenEnabled, isTrue);
        expect(fake.startCount, 1);
        expect(fake.stopCount, 0);

        await fake.startChime();
        expect(fake.isPlaying, isTrue);
        expect(fake.startCount, 2);

        await fake.stopChime();
        await fake.setWakeScreen(false);

        expect(fake.isPlaying, isFalse);
        expect(fake.wakeScreenEnabled, isFalse);
        expect(fake.startCount, 2);
        expect(fake.stopCount, 1);
      },
    );
  });

  group('alarmAudioGatewayProvider', () {
    test('defaults to MethodChannelAlarmAudioGateway', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(alarmAudioGatewayProvider),
        isA<MethodChannelAlarmAudioGateway>(),
      );
    });

    test('supports overriding with FakeAlarmAudioGateway', () async {
      final fake = FakeAlarmAudioGateway();
      final container = ProviderContainer(
        overrides: [alarmAudioGatewayProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final gateway = container.read(alarmAudioGatewayProvider);
      expect(gateway, same(fake));

      await gateway.startChime();
      expect(fake.isPlaying, isTrue);
      expect(fake.startCount, 1);
    });
  });
}
