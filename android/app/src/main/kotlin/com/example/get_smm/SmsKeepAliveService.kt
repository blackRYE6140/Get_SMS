package com.example.get_smm

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class SmsKeepAliveService : Service() {

    private var stopRequestedByUser = false

    override fun onCreate() {
        super.onCreate()
        startForegroundInternal()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRequestedByUser = true
            cancelRestartAlarm(applicationContext)
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        stopRequestedByUser = false
        startForegroundInternal()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!stopRequestedByUser) {
            scheduleRestartAlarm(applicationContext)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (!stopRequestedByUser) {
            scheduleRestartAlarm(applicationContext)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundInternal() {
        createNotificationChannel()
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent =
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

        val pendingIntent =
            launchIntent?.let {
                PendingIntent.getActivity(
                    this,
                    0,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }

        val builder =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Auto SMS actif")
                .setContentText("Surveillance SMS en arriere-plan")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Auto SMS Service",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Maintient la capture SMS en arriere-plan"
                setShowBadge(false)
                setSound(null, null)
            }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val TAG = "SmsKeepAliveService"
        private const val CHANNEL_ID = "auto_sms_background_channel"
        private const val NOTIFICATION_ID = 1042
        private const val RESTART_REQUEST_CODE = 1043
        private const val RESTART_DELAY_MS = 1500L

        private const val ACTION_START = "com.example.get_smm.action.START_KEEP_ALIVE"
        private const val ACTION_STOP = "com.example.get_smm.action.STOP_KEEP_ALIVE"
        private const val ACTION_RESTART = "com.example.get_smm.action.RESTART_KEEP_ALIVE"

        internal const val ACTION_RESTART_ALARM =
            "com.example.get_smm.action.RESTART_KEEP_ALIVE_ALARM"

        fun start(context: Context) {
            startServiceCompat(context, ACTION_START)
        }

        fun stop(context: Context) {
            startServiceCompat(context, ACTION_STOP)
        }

        internal fun startFromAlarm(context: Context) {
            startServiceCompat(context, ACTION_RESTART)
        }

        internal fun scheduleRestartAlarm(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent =
                buildRestartPendingIntent(
                    context,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ) ?: return
            val triggerAtMillis = System.currentTimeMillis() + RESTART_DELAY_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
        }

        internal fun cancelRestartAlarm(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = buildRestartPendingIntent(
                context,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            pendingIntent?.let {
                alarmManager.cancel(it)
                it.cancel()
            }
        }

        private fun buildRestartPendingIntent(
            context: Context,
            flags: Int,
        ): PendingIntent? {
            val intent = Intent(context, KeepAliveRestartReceiver::class.java).apply {
                action = ACTION_RESTART_ALARM
            }
            return PendingIntent.getBroadcast(
                context,
                RESTART_REQUEST_CODE,
                intent,
                flags,
            )
        }

        private fun startServiceCompat(context: Context, action: String) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, SmsKeepAliveService::class.java).apply {
                this.action = action
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appContext.startForegroundService(intent)
                } else {
                    appContext.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unable to start keep-alive service for action: $action", e)
            }
        }
    }
}
