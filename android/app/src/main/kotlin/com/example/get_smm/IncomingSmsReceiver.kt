package com.example.get_smm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class IncomingSmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val appContext = context.applicationContext

        // Best effort: keep the foreground service alive for next events.
        runCatching { SmsKeepAliveService.start(appContext) }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isEmpty()) {
                return
            }

            val firstMessage = messages.first()
            val address =
                firstMessage.displayOriginatingAddress
                    ?: firstMessage.originatingAddress
                    ?: ""
            val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
            val date = toIsoDate(firstMessage.timestampMillis)

            // Keep a fallback queue first, then try immediate DB persistence.
            PendingSmsStore.enqueue(appContext, address, body, date)

            val dbHelper = SmsDatabaseHelper(appContext)
            try {
                dbHelper.saveMessage(address = address, body = body, date = date)
                PendingSmsStore.remove(appContext, address, body, date)
            } finally {
                dbHelper.close()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Background SMS capture failed", e)
        }
    }

    private fun toIsoDate(timestampMillis: Long): String {
        val safeTimestamp = if (timestampMillis > 0L) {
            timestampMillis
        } else {
            System.currentTimeMillis()
        }

        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
        return formatter.format(Date(safeTimestamp))
    }

    private companion object {
        private const val TAG = "IncomingSmsReceiver"
    }
}
