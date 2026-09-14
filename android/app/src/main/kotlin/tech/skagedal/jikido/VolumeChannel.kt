package tech.skagedal.jikido

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The alarm volume, which is the one the bell plays at, for the indicator
 * on the Dart side. Reads only: the volume is the side buttons' business.
 */
class VolumeChannel(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val audioManager =
        context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val resolver = context.applicationContext.contentResolver
    private val methods = MethodChannel(messenger, "jikido/volume")
    private val events = EventChannel(messenger, "jikido/volume/changes")

    private var sink: EventChannel.EventSink? = null
    private var lastSent = -1

    // Volume changes are written to the system settings, and so notify
    // observers of them, along with every other setting: hence the check
    // that this stream actually moved.
    private val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) {
            val current = audioManager.getStreamVolume(STREAM)
            if (current != lastSent) {
                lastSent = current
                sink?.success(snapshot(current))
            }
        }
    }

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "get" -> result.success(snapshot(audioManager.getStreamVolume(STREAM)))
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        lastSent = audioManager.getStreamVolume(STREAM)
        resolver.registerContentObserver(Settings.System.CONTENT_URI, true, observer)
    }

    override fun onCancel(arguments: Any?) {
        resolver.unregisterContentObserver(observer)
        sink = null
    }

    fun dispose() {
        onCancel(null)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    private fun snapshot(volume: Int): Map<String, Any> {
        val max = audioManager.getStreamMaxVolume(STREAM)
        return mapOf(
            "level" to if (max > 0) volume.toDouble() / max else 0.0,
            "steps" to max,
        )
    }

    companion object {
        const val STREAM = AudioManager.STREAM_ALARM
    }
}
