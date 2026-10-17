package com.jdmakes.wyrm

import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val displayChannelName = "wyrm_desk/display"
    private val tag = "WyrmDisplay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, displayChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Applies a window-level brightness override so the panel can be dimmed.
                    "setPanelState" -> {
                        val brightness = call.argument<Double>("brightness") ?: 1.0
                        Log.d(tag, "setPanelState brightness=$brightness")
                        try {
                            applyPanelBrightness(brightness)
                            result.success(true)
                        } catch (error: Exception) {
                            Log.e(tag, "setPanelState failed", error)
                            result.error("PANEL_STATE_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyPanelBrightness(brightness: Double) {
        runOnUiThread {
            val attributes = window.attributes
            attributes.screenBrightness = brightness.toFloat().coerceIn(0.01f, 1.0f)
            window.attributes = attributes
        }
    }
}
