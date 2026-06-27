// android/app/src/main/kotlin/com/whispr/app/CountdownForegroundService.kt
//
// Section 7.6 — Android Live Activity Equivalent
//
// A lightweight Foreground Service that shows and ticks a persistent
// "countdown" notification, matching the Countdown Ring visual spec
// (Section 3.5) as closely as Android's notification framework allows.
//
// Integration with Flutter:
//   MainActivity.kt receives MethodChannel calls from LiveActivityService.dart
//   and forwards them to this service via startService() / stopService() Intents.

package com.whispr.app

import android.app.*
import android.content.Intent
import android.os.IBinder
import android.os.Build
import android.graphics.*
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import kotlin.math.max

class CountdownForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "whispr_countdown"
        const val NOTIFICATION_ID = 9001

        // Intent extras
        const val EXTRA_TITLE       = "task_title"
        const val EXTRA_FIRE_AT     = "fire_at_millis"
        const val EXTRA_LABEL       = "label"
        const val EXTRA_IS_MERGED   = "is_merged"
        const val EXTRA_COUNT       = "merged_count"
        const val ACTION_START      = "com.whispr.app.ACTION_START_COUNTDOWN"
        const val ACTION_STOP       = "com.whispr.app.ACTION_STOP_COUNTDOWN"
    }

    private val scheduler = Executors.newSingleThreadScheduledExecutor()
    private var tickJob: ScheduledFuture<*>? = null
    private var taskTitle: String = "Upcoming reminder"
    private var fireAtMillis: Long = 0L
    private var label: String = ""
    private var isMerged: Boolean = false
    private var mergedCount: Int = 1

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopCountdown()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                taskTitle     = intent?.getStringExtra(EXTRA_TITLE)     ?: "Upcoming reminder"
                fireAtMillis  = intent?.getLongExtra(EXTRA_FIRE_AT, 0L) ?: 0L
                label         = intent?.getStringExtra(EXTRA_LABEL)     ?: ""
                isMerged      = intent?.getBooleanExtra(EXTRA_IS_MERGED, false) ?: false
                mergedCount   = intent?.getIntExtra(EXTRA_COUNT, 1)     ?: 1
                startCountdown()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        tickJob?.cancel(true)
        scheduler.shutdown()
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Countdown
    // -------------------------------------------------------------------------

    private fun startCountdown() {
        // Start in foreground immediately with the initial notification.
        startForeground(NOTIFICATION_ID, buildNotification())

        // Tick every second to update the countdown text.
        tickJob?.cancel(true)
        tickJob = scheduler.scheduleAtFixedRate({
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification())

            // Auto-stop when the timer hits zero.
            if (System.currentTimeMillis() >= fireAtMillis) {
                stopCountdown()
            }
        }, 1L, 1L, TimeUnit.SECONDS)
    }

    private fun stopCountdown() {
        tickJob?.cancel(true)
        stopForeground(true)
        stopSelf()
    }

    // -------------------------------------------------------------------------
    // Notification builder
    // -------------------------------------------------------------------------

    private fun buildNotification(): Notification {
        val remainingMs = max(0L, fireAtMillis - System.currentTimeMillis())
        val countdownText = formatRemaining(remainingMs)

        val title = if (isMerged) {
            "$mergedCount things due soon"
        } else {
            taskTitle
        }

        val body = if (isMerged) {
            "Next: $taskTitle • $countdownText"
        } else if (label.isNotEmpty()) {
            "$label • $countdownText"
        } else {
            countdownText
        }

        // Tap → open app
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            // Draw a progress bar as a rough visual analog of the countdown ring.
            .setProgress(
                100,
                computeProgressPercent(remainingMs),
                false
            )
            .setColor(Color.parseColor("#00C2D1")) // Spark Cyan

        return builder.build()
    }

    private fun formatRemaining(ms: Long): String {
        val totalSeconds = ms / 1000
        val h = totalSeconds / 3600
        val m = (totalSeconds % 3600) / 60
        val s = totalSeconds % 60
        return when {
            h > 0 -> "${h}h ${m}m"
            m > 0 -> "${m}m ${s}s"
            else  -> "${s}s"
        }
    }

    private fun computeProgressPercent(remainingMs: Long): Int {
        val windowMs = 30 * 60 * 1000L // 30 min default
        val elapsed = windowMs - remainingMs
        return (100 * elapsed / windowMs).toInt().coerceIn(0, 100)
    }

    // -------------------------------------------------------------------------
    // Notification channel
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Whispr Countdown",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Live countdown timer for upcoming reminders"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
