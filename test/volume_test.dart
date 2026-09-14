import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jikido/src/volume.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('comparing with the last sitting', () {
    VolumeLevel iphone(int presses) =>
        VolumeLevel(level: presses / 16, steps: 16);

    test('silence is silence, whatever last time was', () {
      expect(iphone(0).compareWith(null), VolumeComparison.silent);
      expect(iphone(0).compareWith(0), VolumeComparison.silent);
    });

    test('with nothing to compare against there is no comparison', () {
      expect(iphone(8).compareWith(null), VolumeComparison.noPrevious);
    });

    test('one press either way is the same', () {
      expect(iphone(8).compareWith(8 / 16), VolumeComparison.same);
      expect(iphone(9).compareWith(8 / 16), VolumeComparison.same);
      expect(iphone(7).compareWith(8 / 16), VolumeComparison.same);
    });

    test('two presses is louder or quieter', () {
      expect(iphone(10).compareWith(8 / 16), VolumeComparison.louder);
      expect(iphone(6).compareWith(8 / 16), VolumeComparison.quieter);
    });

    test('a step is the platform\'s own step', () {
      const android = VolumeLevel(level: 5 / 7, steps: 7);
      expect(android.compareWith(4 / 7), VolumeComparison.same);
      expect(android.compareWith(3 / 7), VolumeComparison.louder);
    });
  });

  group('PlatformVolume', () {
    const channel = MethodChannel('jikido/volume');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('reads the level and the steps', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'get');
        return <String, Object>{'level': 0.25, 'steps': 15};
      });
      expect(await const PlatformVolume().read(),
          const VolumeLevel(level: 0.25, steps: 15));
    });

    test('says nothing when there is no platform side', () async {
      expect(await const PlatformVolume().read(), isNull);
    });

    test('says nothing when the platform side throws', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(await const PlatformVolume().read(), isNull);
    });

    test('says nothing for an answer it does not understand', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => 'loud');
      expect(await const PlatformVolume().read(), isNull);
    });
  });
}
