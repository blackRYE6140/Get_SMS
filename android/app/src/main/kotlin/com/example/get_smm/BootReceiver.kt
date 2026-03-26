package com.example.get_smm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_QUICKBOOT_POWERON,
            -> SmsKeepAliveService.start(context.applicationContext)
        }
    }

    private companion object {
        private const val ACTION_QUICKBOOT_POWERON =
            "android.intent.action.QUICKBOOT_POWERON"
    }
}
