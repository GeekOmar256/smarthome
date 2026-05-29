package com.teacher.teacher_recorder

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton

/**
 * Phase 2: System overlay button rendered on top of all apps.
 * Requires SYSTEM_ALERT_WINDOW permission (granted at runtime via permission_handler).
 *
 * Drag to move; tap to toggle recording; long-press to collapse to a thin strip.
 * Broadcasts com.teacher.OVERLAY_TOGGLE to MainActivity, which routes to Flutter.
 */
class OverlayService : Service() {

    companion object {
        const val ACTION_OVERLAY_TOGGLE = "com.teacher.OVERLAY_TOGGLE"
    }

    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private lateinit var params: WindowManager.LayoutParams

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isCollapsed = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 200
        }

        // Create a simple circular button view programmatically
        overlayView = createOverlayView()
        overlayView.setOnTouchListener(buildTouchListener())
        windowManager.addView(overlayView, params)

        return START_STICKY
    }

    private fun createOverlayView(): View {
        // In production, inflate a proper layout from res/layout/overlay_button.xml
        val button = ImageButton(this)
        button.setImageResource(android.R.drawable.ic_media_play)
        button.setBackgroundResource(android.R.drawable.btn_default_small)
        return button
    }

    private fun buildTouchListener() = View.OnTouchListener { _, event ->
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = params.x
                initialY = params.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                true
            }
            MotionEvent.ACTION_MOVE -> {
                params.x = initialX + (event.rawX - initialTouchX).toInt()
                params.y = initialY + (event.rawY - initialTouchY).toInt()
                windowManager.updateViewLayout(overlayView, params)
                true
            }
            MotionEvent.ACTION_UP -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                val isTap = Math.abs(dx) < 10 && Math.abs(dy) < 10
                if (isTap) sendToggleBroadcast()
                true
            }
            else -> false
        }
    }

    private fun sendToggleBroadcast() {
        sendBroadcast(Intent(ACTION_OVERLAY_TOGGLE))
    }

    override fun onDestroy() {
        if (::overlayView.isInitialized) {
            windowManager.removeView(overlayView)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
