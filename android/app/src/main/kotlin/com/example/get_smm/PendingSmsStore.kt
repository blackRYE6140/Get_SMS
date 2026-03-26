package com.example.get_smm

import android.content.Context
import org.json.JSONObject

object PendingSmsStore {
    private const val PREF_NAME = "pending_sms_store"
    private const val KEY_MESSAGES = "pending_messages"

    fun enqueue(context: Context, address: String, body: String, date: String) {
        val payload = toPayload(address, body, date)
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val messages = prefs.getStringSet(KEY_MESSAGES, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        messages.add(payload)
        prefs.edit().putStringSet(KEY_MESSAGES, messages).apply()
    }

    fun remove(context: Context, address: String, body: String, date: String) {
        val payload = toPayload(address, body, date)
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val messages = prefs.getStringSet(KEY_MESSAGES, emptySet())?.toMutableSet()
            ?: mutableSetOf()

        if (messages.remove(payload)) {
            prefs.edit().putStringSet(KEY_MESSAGES, messages).apply()
        }
    }

    fun flushToDatabase(context: Context): Int {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val pendingMessages = prefs.getStringSet(KEY_MESSAGES, emptySet())?.toList()
            ?: emptyList()

        if (pendingMessages.isEmpty()) return 0

        val dbHelper = SmsDatabaseHelper(context)
        val remaining = mutableSetOf<String>()
        var flushedCount = 0

        try {
            for (payload in pendingMessages) {
                try {
                    val json = JSONObject(payload)
                    val address = json.optString("address", "")
                    val body = json.optString("body", "")
                    val date = json.optString("date", "")

                    if (address.isBlank() && body.isBlank()) {
                        continue
                    }

                    dbHelper.saveMessage(
                        address = address,
                        body = body,
                        date = if (date.isBlank()) currentIsoDate() else date,
                    )
                    flushedCount++
                } catch (_: Exception) {
                    remaining.add(payload)
                }
            }
        } finally {
            dbHelper.close()
        }

        if (remaining.isEmpty()) {
            prefs.edit().remove(KEY_MESSAGES).apply()
        } else {
            prefs.edit().putStringSet(KEY_MESSAGES, remaining).apply()
        }

        return flushedCount
    }

    private fun toPayload(address: String, body: String, date: String): String {
        return JSONObject()
            .put("address", address)
            .put("body", body)
            .put("date", date)
            .toString()
    }

    private fun currentIsoDate(): String {
        val now = System.currentTimeMillis()
        return java.text.SimpleDateFormat(
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            java.util.Locale.US,
        ).format(java.util.Date(now))
    }
}
