package com.dhananjay.lifelens

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.dhananjay.lifelens/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Usage Access ────────────────────────────────────────────
                "openUsageAccessSettings" -> {
                    val intent = android.content.Intent(
                        android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS
                    )
                    startActivity(intent)
                    result.success(null)
                }

                "hasUsageAccessPermission" -> {
                    val appOps = getSystemService(android.content.Context.APP_OPS_SERVICE)
                            as android.app.AppOpsManager
                    val mode = appOps.checkOpNoThrow(
                        android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                        android.os.Process.myUid(),
                        packageName
                    )
                    result.success(mode == android.app.AppOpsManager.MODE_ALLOWED)
                }

                // ── Safety: Emergency Call ──────────────────────────────────
                // Makes a direct call without showing the dialer UI.
                // Requires CALL_PHONE permission.
                "makeEmergencyCall" -> {
                    val number = call.argument<String>("number") ?: "112"
                    try {
                        val intent = android.content.Intent(android.content.Intent.ACTION_CALL).apply {
                            data = android.net.Uri.parse("tel:$number")
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", e.message, null)
                    }
                }

                // ── Safety: Send SMS ────────────────────────────────────────
                // Sends SMS silently via SmsManager — no app chooser shown.
                // Requires SEND_SMS permission.
                // Works offline (no internet needed).
                "sendSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message") ?: ""

                    if (phone.isNullOrBlank()) {
                        result.error("INVALID_PHONE", "Phone number is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val smsManager: android.telephony.SmsManager? =
                            if (android.os.Build.VERSION.SDK_INT >= 31) {
                                applicationContext.getSystemService(android.telephony.SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                android.telephony.SmsManager.getDefault()
                            }

                        if (smsManager == null) {
                            result.error("SMS_ERROR", "SmsManager not available on this device", null)
                            return@setMethodCallHandler
                        }

                        // Divide into parts if message > 160 chars
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
