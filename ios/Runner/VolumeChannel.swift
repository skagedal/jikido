import AVFoundation
import Flutter

/// The output volume, which is the one the bell plays at, for the indicator
/// on the Dart side.
///
/// Reads the shared audio session and nothing more. Its category, options
/// and activation belong to `bell_audio.dart`, and the one guarantee the app
/// makes rests on them.
final class VolumeChannel: NSObject, FlutterStreamHandler {
  /// One press of a volume button.
  private static let steps = 16

  private let session = AVAudioSession.sharedInstance()
  private let methods: FlutterMethodChannel
  private let events: FlutterEventChannel
  private var observation: NSKeyValueObservation?
  private var sink: FlutterEventSink?

  init(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "jikido/volume", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "jikido/volume/changes", binaryMessenger: messenger)
    super.init()
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "get":
        result(Self.snapshot(self.session.outputVolume))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    events.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    // Only reported while the session is active, which it is once anything
    // has played.
    observation = session.observe(\.outputVolume, options: [.new]) { [weak self] session, _ in
      let volume = session.outputVolume
      DispatchQueue.main.async {
        self?.sink?(Self.snapshot(volume))
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    observation?.invalidate()
    observation = nil
    sink = nil
    return nil
  }

  private static func snapshot(_ volume: Float) -> [String: Any] {
    ["level": Double(volume), "steps": steps]
  }
}
