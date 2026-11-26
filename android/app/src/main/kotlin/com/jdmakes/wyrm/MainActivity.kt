package com.jdmakes.wyrm

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {

    private val displayChannelName = "wyrm_desk/display"
    private val backupChannelName = "wyrm_desk/backup"
    private val alarmChannelName = "wyrm_desk/alarm"
    private val sharingChannelName = "wyrm_desk/sharing"
    private val tag = "WyrmDesk"

    private val saveBackupRequest = 4101
    private val openBackupRequest = 4102
    private val importSharingFileRequest = 4103
    private val legacyStoragePermissionRequest = 4104

    private var alarmPlayer: MediaPlayer? = null

    // Backup transfers are asynchronous: the method call stays pending until the
    // system document picker returns, then these hold the reply to send back.
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveContents: String? = null
    private var pendingOpenResult: MethodChannel.Result? = null
    private var pendingImportResult: MethodChannel.Result? = null
    private var pendingImportTargetDir: String? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarmChime" -> result.success(startAlarmChime())
                    "stopAlarmChime" -> {
                        stopAlarmChime()
                        result.success(null)
                    }
                    "setWakeScreen" -> {
                        val enabled = when (val args = call.arguments) {
                            is Boolean -> args
                            is Map<*, *> -> (args["enabled"] as? Boolean) ?: false
                            else -> false
                        }
                        setWakeScreen(enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sharingChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "requestAllFilesAccess" -> result.success(requestAllFilesAccess())
                    "openFile" -> openSharedFile(call, result)
                    "pickImportFile" -> pickImportFile(call, result)
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
    // ALARM AUDIO & WAKE SCREEN
    // =========================================================================

    private fun startAlarmChime(): Boolean {
        releaseAlarmPlayer()
        cancelAlarmVibration()
        setKeepScreenOn(true)
        startAlarmVibration()

        val candidateUris = listOfNotNull(
            safeDefaultRingtoneUri(RingtoneManager.TYPE_ALARM),
            safeDefaultRingtoneUri(RingtoneManager.TYPE_NOTIFICATION),
            safeDefaultRingtoneUri(RingtoneManager.TYPE_RINGTONE)
        ).distinct()

        for (uri in candidateUris) {
            var player: MediaPlayer? = null
            try {
                player = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(applicationContext, uri)
                    isLooping = true
                    prepare()
                    start()
                }
                alarmPlayer = player
                return true
            } catch (error: Exception) {
                Log.w(tag, "Could not start alarm chime for $uri", error)
                try {
                    player?.release()
                } catch (_: Exception) {
                }
            }
        }

        Log.w(tag, "No playable alarm ringtone URI available")
        return false
    }

    private fun stopAlarmChime() {
        releaseAlarmPlayer()
        cancelAlarmVibration()
        setKeepScreenOn(false)
    }

    private fun safeDefaultRingtoneUri(type: Int): Uri? {
        return try {
            RingtoneManager.getDefaultUri(type)
        } catch (error: Exception) {
            Log.w(tag, "Could not resolve default ringtone URI for type=$type", error)
            null
        }
    }

    private fun releaseAlarmPlayer() {
        val player = alarmPlayer ?: return
        alarmPlayer = null
        try {
            if (player.isPlaying) {
                player.stop()
            }
        } catch (_: Exception) {
        }
        try {
            player.release()
        } catch (_: Exception) {
        }
    }

    private fun resolveVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager =
                    getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                manager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
        } catch (error: Exception) {
            Log.w(tag, "Could not resolve Vibrator service", error)
            null
        }
    }

    private fun startAlarmVibration() {
        try {
            val vibrator = resolveVibrator() ?: return
            if (!vibrator.hasVibrator()) return
            val pattern = longArrayOf(0L, 350L, 650L)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
            }
        } catch (error: Exception) {
            Log.w(tag, "Could not start alarm vibration", error)
        }
    }

    private fun cancelAlarmVibration() {
        try {
            resolveVibrator()?.cancel()
        } catch (error: Exception) {
            Log.w(tag, "Could not cancel alarm vibration", error)
        }
    }

    private fun setKeepScreenOn(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    private fun setWakeScreen(enabled: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(enabled)
                setTurnScreenOn(enabled)
            } else {
                @Suppress("DEPRECATION")
                val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                if (enabled) {
                    window.addFlags(flags)
                } else {
                    window.clearFlags(flags)
                }
            }
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
            importSharingFileRequest -> finishImportSharingFile(uri)
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

    // =========================================================================
    // SHARING - All Files Access, External Open & SAF Import
    // =========================================================================

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestAllFilesAccess(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val appIntent = Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                try {
                    startActivity(appIntent)
                } catch (_: Exception) {
                    startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                }
                true
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(
                    arrayOf(
                        Manifest.permission.READ_EXTERNAL_STORAGE,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ),
                    legacyStoragePermissionRequest
                )
                true
            } else {
                true
            }
        } catch (error: Exception) {
            Log.e(tag, "Could not request all files access", error)
            false
        }
    }

    private fun openSharedFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "No file path provided", null)
            return
        }
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            result.error("NOT_FOUND", "Shared file does not exist", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file
            )
            val mimeType = call.argument<String>("mimeType") ?: "*/*"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, file.name))
            result.success(true)
        } catch (error: Exception) {
            Log.e(tag, "Could not open shared file $path", error)
            result.error("OPEN_FAILED", error.message ?: "No viewer available", null)
        }
    }

    private fun pickImportFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingImportResult != null) {
            result.error("BUSY", "A file import is already in progress", null)
            return
        }
        val targetDir = call.argument<String>("targetDir")
        if (targetDir.isNullOrBlank()) {
            result.error("INVALID_DIR", "No target directory provided", null)
            return
        }
        pendingImportResult = result
        pendingImportTargetDir = targetDir
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            startActivityForResult(intent, importSharingFileRequest)
        } catch (error: Exception) {
            pendingImportResult = null
            pendingImportTargetDir = null
            Log.e(tag, "Could not open import document picker", error)
            result.error("IMPORT_FAILED", error.message ?: "No file picker available", null)
        }
    }

    private fun finishImportSharingFile(uri: Uri?) {
        val result = pendingImportResult
        val targetDirPath = pendingImportTargetDir
        pendingImportResult = null
        pendingImportTargetDir = null

        if (uri == null || targetDirPath == null) {
            result?.success(null)
            return
        }
        try {
            val targetDir = File(targetDirPath).apply { mkdirs() }
            val rawName = displayName(uri) ?: "imported_${System.currentTimeMillis()}"
            val cleanName = rawName.replace("/", "_").replace("\\", "_")
            val destination = resolveUniqueDestination(targetDir, cleanName)
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("Could not open selected file for reading")
            input.use { src ->
                destination.outputStream().use { dst ->
                    src.copyTo(dst, bufferSize = 64 * 1024)
                    dst.flush()
                }
            }
            result?.success(destination.name)
        } catch (error: Exception) {
            Log.e(tag, "Sharing import failed", error)
            result?.error("IMPORT_FAILED", error.message ?: "Could not import file", null)
        }
    }

    private fun resolveUniqueDestination(dir: File, fileName: String): File {
        var candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate

        val dotIndex = fileName.lastIndexOf('.')
        val stem = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val ext = if (dotIndex > 0) fileName.substring(dotIndex) else ""
        var counter = 1
        while (candidate.exists()) {
            candidate = File(dir, "$stem ($counter)$ext")
            counter++
        }
        return candidate
    }

    override fun onDestroy() {
        releaseAlarmPlayer()
        cancelAlarmVibration()
        // A picker still open when the activity dies would otherwise leave Dart
        // awaiting forever; resolve all pending results as cancellations.
        pendingSaveResult?.success(null)
        pendingOpenResult?.success(null)
        pendingImportResult?.success(null)
        pendingSaveResult = null
        pendingSaveContents = null
        pendingOpenResult = null
        pendingImportResult = null
        pendingImportTargetDir = null
        super.onDestroy()
    }
}
