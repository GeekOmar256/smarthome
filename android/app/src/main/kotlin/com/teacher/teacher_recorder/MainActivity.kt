package com.teacher.teacher_recorder

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.projection.MediaProjectionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.teacher.teacher_recorder/recording"
        private const val REQUEST_MEDIA_PROJECTION = 1001
        private const val ACTION_OVERLAY_TOGGLE = "com.teacher.OVERLAY_TOGGLE"
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingOutputPath: String? = null

    // Receives toggle signals from OverlayService (Phase 2)
    private val overlayReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            // Route to Flutter via EventChannel or MethodChannel callback
            // For simplicity, emit via a separate EventChannel in production
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        val outputPath = call.argument<String>("outputPath")
                            ?: return@setMethodCallHandler result.error(
                                "INVALID_ARGS", "outputPath is required", null
                            )
                        pendingOutputPath = outputPath
                        pendingResult = result
                        requestMediaProjection()
                    }
                    "stopRecording" -> {
                        stopForegroundRecordingService()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestMediaProjection() {
        val mpManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mpManager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_MEDIA_PROJECTION) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.error("PERMISSION_DENIED", "Screen capture permission denied", null)
            pendingResult = null
            return
        }

        val intent = Intent(this, RecordingService::class.java).apply {
            action = RecordingService.ACTION_START
            putExtra(RecordingService.EXTRA_RESULT_CODE, resultCode)
            putExtra(RecordingService.EXTRA_RESULT_DATA, data)
            putExtra(RecordingService.EXTRA_OUTPUT_PATH, pendingOutputPath)
        }
        startForegroundService(intent)
        pendingResult?.success(null)
        pendingResult = null
    }

    private fun stopForegroundRecordingService() {
        val intent = Intent(this, RecordingService::class.java).apply {
            action = RecordingService.ACTION_STOP
        }
        startService(intent)
    }

    override fun onStart() {
        super.onStart()
        registerReceiver(overlayReceiver, IntentFilter(ACTION_OVERLAY_TOGGLE),
            RECEIVER_NOT_EXPORTED)
    }

    override fun onStop() {
        super.onStop()
        unregisterReceiver(overlayReceiver)
    }
}
