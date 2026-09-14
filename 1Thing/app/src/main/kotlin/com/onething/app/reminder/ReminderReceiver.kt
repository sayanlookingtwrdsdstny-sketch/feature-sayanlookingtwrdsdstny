package com.onething.app.reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.onething.app.data.GoalDatabase
import com.onething.app.data.GoalRepository
import com.onething.app.data.UserPreferencesRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Fires once a day at the configured time. Skips the notification if today's goal is already
 * completed, then reschedules itself for the next day — never marks anything complete/incomplete.
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prefsRepository = UserPreferencesRepository(context)
                val prefs = prefsRepository.preferences.first()

                if (prefs.reminder.enabled) {
                    val goalRepository = GoalRepository(GoalDatabase.getDatabase(context).goalDao())
                    val todayGoal = goalRepository.getTodayGoal().first()
                    if (todayGoal?.completed != true) {
                        NotificationHelper.showReminder(context)
                    }
                    ReminderScheduler.schedule(context, prefs.reminder.hour, prefs.reminder.minute)
                }
            } finally {
                pendingResult.finish()
            }
        }
    }
}
