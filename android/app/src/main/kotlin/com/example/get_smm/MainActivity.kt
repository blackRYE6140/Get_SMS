package com.example.get_smm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_SMS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "flushPendingSms" -> {
                    try {
                        val flushed =
                            PendingSmsStore.flushToDatabase(applicationContext)
                        result.success(flushed)
                    } catch (e: Exception) {
                        result.error(
                            "FLUSH_PENDING_SMS_FAILED",
                            e.message,
                            null,
                        )
                    }
                }

                "startKeepAliveService" -> {
                    try {
                        SmsKeepAliveService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "START_KEEP_ALIVE_FAILED",
                            e.message,
                            null,
                        )
                    }
                }

                "stopKeepAliveService" -> {
                    try {
                        SmsKeepAliveService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "STOP_KEEP_ALIVE_FAILED",
                            e.message,
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        private const val BACKGROUND_SMS_CHANNEL = "get_smm/background_sms"
    }
}
