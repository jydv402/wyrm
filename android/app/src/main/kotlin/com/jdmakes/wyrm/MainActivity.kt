package com.jdmakes.wyrm

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {

    private val displayChannelName = "wyrm_desk/display"
    private val backupChannelName = "wyrm_desk/backup"
    private val tag = "WyrmDesk"

    private val saveBackupRequest = 4101
    private val openBackupRequest = 4102

    // Backup transfers are asynchronous: the method call stays pending until the
    // system document picker returns, then these hold the reply to send back.
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveContents: String? = null
    private var pendingOpenResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBackup" -> saveBackup(call, result)
                    "openBackup" -> openBackup(result)
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

    // =========================================================================
    // BACKUP TRANSFER - Storage Access Framework
    //
    // Public directories such as /storage/emulated/0/Download are not writable
    // by an app on Android 10+ without MANAGE_EXTERNAL_STORAGE. The system
    // picker instead grants access to exactly the document the person chose, so
    // no storage permission is declared or requested.
    // =========================================================================

    private fun saveBackup(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSaveResult != null) {
            result.error("BUSY", "A backup save is already in progress", null)
            return
        }
        val contents = call.argument<String>("contents")
        if (contents == null) {
            result.error("SAVE_FAILED", "No backup contents were provided", null)
            return
        }
        val fileName = call.argument<String>("fileName") ?: "wyrm_backup.json"
        pendingSaveResult = result
        pendingSaveContents = contents
        try {
            startActivityForResult(createBackupIntent(fileName), saveBackupRequest)
        } catch (error: Exception) {
            pendingSaveResult = null
            pendingSaveContents = null
            Log.e(tag, "Could not open the save picker", error)
            result.error("SAVE_FAILED", error.message ?: "No file picker is available", null)
        }
    }

    private fun openBackup(result: MethodChannel.Result) {
        if (pendingOpenResult != null) {
            result.error("BUSY", "A backup import is already in progress", null)
            return
        }
        pendingOpenResult = result
        try {
            startActivityForResult(openBackupIntent(), openBackupRequest)
        } catch (error: Exception) {
            pendingOpenResult = null
            Log.e(tag, "Could not open the import picker", error)
            result.error("READ_FAILED", error.message ?: "No file picker is available", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri = if (resultCode == RESULT_OK) data?.data else null
        when (requestCode) {
            saveBackupRequest -> finishSave(uri)
            openBackupRequest -> finishOpen(uri)
        }
    }

    private fun finishSave(uri: Uri?) {
        val result = pendingSaveResult
        val contents = pendingSaveContents
        pendingSaveResult = null
        pendingSaveContents = null

        if (uri == null) {
            result?.success(null) // The picker reports cancellation as no value.
            return
        }
        if (contents == null) {
            result?.error("SAVE_FAILED", "No backup contents were provided", null)
            return
        }
        try {
            // "wt" truncates, so re-saving over an existing document replaces it
            // instead of leaving stale bytes past the new end.
            val stream = contentResolver.openOutputStream(uri, "wt")
                ?: throw IOException("The selected file could not be opened for writing")
            stream.use {
                it.write(contents.toByteArray(Charsets.UTF_8))
                it.flush()
            }
            val name = displayName(uri) ?: uri.toString()
            Log.d(tag, "Backup saved to $name")
            result?.success(name)
        } catch (error: Exception) {
            Log.e(tag, "Backup save failed", error)
            result?.error("SAVE_FAILED", error.message ?: "The backup could not be saved", null)
        }
    }

    private fun finishOpen(uri: Uri?) {
        val result = pendingOpenResult
        pendingOpenResult = null

        if (uri == null) {
            result?.success(null)
            return
        }
        try {
            val reader = contentResolver.openInputStream(uri)
                ?.bufferedReader(Charsets.UTF_8)
                ?: throw IOException("The selected file could not be opened for reading")
            val text = reader.use { it.readText() }
            val name = displayName(uri) ?: uri.toString()
            Log.d(tag, "Backup read from $name (${text.length} chars)")
            result?.success(mapOf("name" to name, "contents" to text))
        } catch (error: Exception) {
            Log.e(tag, "Backup read failed", error)
            result?.error("READ_FAILED", error.message ?: "The backup could not be read", null)
        }
    }

    private fun createBackupIntent(fileName: String): Intent {
        return Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
    }

    private fun openBackupIntent(): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            // JSON is typed inconsistently across providers, so accept the
            // obvious text types instead of hiding a readable backup.
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/plain", "application/octet-stream")
            )
        }
    }

    private fun displayName(uri: Uri): String? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            }
        } catch (error: Exception) {
            Log.w(tag, "Could not resolve display name for $uri", error)
            null
        }
    }

    override fun onDestroy() {
        // A picker still open when the activity dies would otherwise leave Dart
        // awaiting forever; resolve both as cancellations.
        pendingSaveResult?.success(null)
        pendingOpenResult?.success(null)
        pendingSaveResult = null
        pendingSaveContents = null
        pendingOpenResult = null
        super.onDestroy()
    }
}
