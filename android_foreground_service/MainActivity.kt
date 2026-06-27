// android/app/src/main/kotlin/com/whispr/app/MainActivity.kt
//
// Extends FlutterActivity with the MethodChannel bridge that receives
// LiveActivityService.dart calls and dispatches them to
// CountdownForegroundService via Android Intents.
//
// Replace the existing MainActivity.kt (which typically just extends
// FlutterActivity) with this file.

package com.whispr.app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.whispr.app/live_activity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSingleActivity" -> {
                        val args = call.arguments as? Map<*, *>
                        val title   = args?.get("title") as? String ?: "Reminder"
                        val fireAt  = (args?.get("fireAt") as? String)
                            ?.let { parseIso8601(it) } ?: 0L
                        val label   = args?.get("label") as? String ?: ""
                        startCountdownService(title, fireAt, label, false, 1)
                        result.success(null)
                    }
                    "startMergedActivity" -> {
                        val args = call.arguments as? Map<*, *>
                        val nearestTitle = args?.get("nearestTitle") as? String ?: "Reminders"
                        val fireAt = (args?.get("nearestFireAt") as? String)
                            ?.let { parseIso8601(it) } ?: 0L
                        val count = (args?.get("count") as? Int) ?: 2
                        startCountdownService(nearestTitle, fireAt, "", true, count)
                        result.success(null)
                    }
                    "endActivity", "endAllActivities" -> {
                        stopService(
                            Intent(this, CountdownForegroundService::class.java)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startCountdownService(
        title: String,
        fireAtMillis: Long,
        label: String,
        isMerged: Boolean,
        count: Int
    ) {
        val intent = Intent(this, CountdownForegroundService::class.java).apply {
            action = CountdownForegroundService.ACTION_START
            putExtra(CountdownForegroundService.EXTRA_TITLE, title)
            putExtra(CountdownForegroundService.EXTRA_FIRE_AT, fireAtMillis)
            putExtra(CountdownForegroundService.EXTRA_LABEL, label)
            putExtra(CountdownForegroundService.EXTRA_IS_MERGED, isMerged)
            putExtra(CountdownForegroundService.EXTRA_COUNT, count)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    /** Parse an ISO 8601 string into epoch milliseconds. */
    private fun parseIso8601(s: String): Long {
        return try {
            java.time.Instant.parse(s).toEpochMilli()
        } catch (_: Exception) {
            System.currentTimeMillis()
        }
    }
}
