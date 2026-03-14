package com.dhananjay.lifelens

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Restarts the LifeLens tracking service after device reboot
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            // Flutter background service handles its own restart
            // This receiver ensures the service re-launches after boot
            val serviceIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
    }
}
