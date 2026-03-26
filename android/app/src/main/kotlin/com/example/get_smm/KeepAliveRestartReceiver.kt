package com.example.get_smm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class KeepAliveRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != SmsKeepAliveService.ACTION_RESTART_ALARM) {
            return
        }

        SmsKeepAliveService.startFromAlarm(context.applicationContext)
    }
}
