package tech.skagedal.jikido

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var volume: VolumeChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The bell plays on the alarm stream, so while Jikido is in front the
        // side buttons turn that up and down rather than the media volume,
        // which has nothing to do with the bell.
        volumeControlStream = VolumeChannel.STREAM
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volume = VolumeChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        volume?.dispose()
        volume = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
