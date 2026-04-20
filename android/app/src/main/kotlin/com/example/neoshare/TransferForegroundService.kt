package com.example.neoshare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class TransferForegroundService : Service() {

    companion object {
        private const val TAG = "NeoShare[FGService]"
        private const val CHANNEL_ID = "neoshare_upload"
        private const val NOTIF_ID = 1001
        private const val COMPLETE_NOTIF_ID = 1002

        const val EXTRA_TRANSFER_ID = "extra_transfer_id"
        const val EXTRA_ACTION = "extra_action"
        const val EXTRA_PROGRESS = "extra_progress"

        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val ACTION_COMPLETE = "complete"
        const val ACTION_FAILED = "failed"
        const val ACTION_PAUSE = "pause"

        /** Called from Flutter (via MainActivity) to update the progress notification. */
        fun updateProgress(context: Context, percent: Int) {
            val notification = buildProgressNotification(context, percent)
            NotificationManagerCompat.from(context).notify(NOTIF_ID, notification)
            Log.d(TAG, "updateProgress: $percent%")
        }

        /** Called when app is removed from recents — shows paused state. */
        fun showPausedNotification(context: Context) {
            val launchIntent =
                    context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
            val pendingIntent =
                    PendingIntent.getActivity(
                            context,
                            0,
                            launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
            val notification =
                    NotificationCompat.Builder(context, CHANNEL_ID)
                            .setContentTitle("NeoShare — Upload Paused")
                            .setContentText("Tap to reopen the app and resume your transfer.")
                            .setSmallIcon(android.R.drawable.stat_sys_upload)
                            .setOngoing(true)
                            .setOnlyAlertOnce(true)
                            .setSilent(true)
                            .setContentIntent(pendingIntent)
                            .build()
            NotificationManagerCompat.from(context).notify(NOTIF_ID, notification)
            Log.i(TAG, "showPausedNotification")
        }

        private fun buildProgressNotification(context: Context, percent: Int): Notification {
            val indeterminate = percent == 0
            // Tapping the progress notification opens the app to the send page
            val launchIntent =
                    context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
            val pendingIntent =
                    PendingIntent.getActivity(
                            context,
                            0,
                            launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                    .setContentTitle("NeoShare — Uploading")
                    .setContentText(
                            if (indeterminate) "Starting upload…" else "Uploading… $percent%"
                    )
                    .setSmallIcon(android.R.drawable.stat_sys_upload)
                    .setProgress(100, percent, indeterminate)
                    .setOngoing(true)
                    .setOnlyAlertOnce(true)
                    .setSilent(true)
                    .setContentIntent(pendingIntent)
                    .build()
        }
    }

    // ─── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.i(TAG, "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra(EXTRA_ACTION) ?: ACTION_START
        Log.i(TAG, "onStartCommand action=$action")

        return when (action) {
            ACTION_COMPLETE -> {
                postCompletionNotification()
                stopSelf()
                START_NOT_STICKY
            }
            ACTION_FAILED -> {
                postFailureNotification()
                stopSelf()
                START_NOT_STICKY
            }
            ACTION_STOP -> {
                stopSelf()
                START_NOT_STICKY
            }
            else -> {
                // ACTION_START or OS restart (intent may be null on restart)
                startForeground(NOTIF_ID, buildProgressNotification(this, 0))
                START_STICKY
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // User swiped the app from recents while upload was in progress.
        // The service survives (stopWithTask="false"), but the Dart isolate is dead.
        // Show a paused notification so the user knows to reopen the app.
        Log.i(TAG, "onTaskRemoved — switching to paused notification")
        showPausedNotification(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "onDestroy")
    }

    // ─── Notification helpers ──────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    CHANNEL_ID,
                                    "NeoShare Uploads",
                                    NotificationManager.IMPORTANCE_LOW
                            )
                            .apply {
                                description = "Shows upload progress for active file transfers"
                                setSound(null, null)
                                enableVibration(false)
                            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel '$CHANNEL_ID' created")
        }
    }

    private fun postCompletionNotification() {
        val notification =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle("Transfer complete")
                        .setContentText("Your files have been sent successfully.")
                        .setSmallIcon(android.R.drawable.stat_sys_upload_done)
                        .setAutoCancel(true)
                        .build()
        NotificationManagerCompat.from(this).apply {
            cancel(NOTIF_ID)
            notify(COMPLETE_NOTIF_ID, notification)
        }
        Log.i(TAG, "Posted completion notification")
    }

    private fun postFailureNotification() {
        // Deep-link intent to reopen the app so the user can retry
        val retryIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent =
                PendingIntent.getActivity(
                        this,
                        0,
                        retryIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
        val notification =
                NotificationCompat.Builder(this, CHANNEL_ID)
                        .setContentTitle("Transfer failed")
                        .setContentText("Transfer failed. Tap to retry.")
                        .setSmallIcon(android.R.drawable.stat_notify_error)
                        .setAutoCancel(true)
                        .setContentIntent(pendingIntent)
                        .build()
        NotificationManagerCompat.from(this).apply {
            cancel(NOTIF_ID)
            notify(COMPLETE_NOTIF_ID, notification)
        }
        Log.i(TAG, "Posted failure notification")
    }
}
