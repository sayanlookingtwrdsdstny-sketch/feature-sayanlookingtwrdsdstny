package com.onething.app.reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.onething.app.data.UserPreferencesRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/** Alarms don't survive a reboot — re-arm the reminder if the user had it enabled. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prefs = UserPreferencesRepository(context).preferences.first()
                if (prefs.reminder.enabled) {
                    ReminderScheduler.schedule(context, prefs.reminder.hour, prefs.reminder.minute)
                }
            } finally {
                pendingResult.finish()
            }
        }
    }
}
