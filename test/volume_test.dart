import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jikido/src/volume.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
