package com.onething.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.onething.app.data.GoalRepository
import com.onething.app.data.ThemeMode
import com.onething.app.data.UserPreferences
import com.onething.app.data.UserPreferencesRepository
import com.onething.app.reminder.ReminderScheduler
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SettingsViewModel(
    application: Application,
    private val preferencesRepository: UserPreferencesRepository,
    private val goalRepository: GoalRepository
) : AndroidViewModel(application) {

    private val _preferences = MutableStateFlow(UserPreferences())
    val preferences: StateFlow<UserPreferences> = _preferences.asStateFlow()

    private val _dataCleared = MutableStateFlow(false)
    val dataCleared: StateFlow<Boolean> = _dataCleared.asStateFlow()

    init {
        viewModelScope.launch {
            preferencesRepository.preferences.collect { _preferences.value = it }
        }
    }

    fun setReminderEnabled(enabled: Boolean) {
        val current = _preferences.value.reminder
        applyReminder(enabled, current.hour, current.minute)
    }

    fun setReminderTime(hour: Int, minute: Int) {
        applyReminder(_preferences.value.reminder.enabled, hour, minute)
    }

    private fun applyReminder(enabled: Boolean, hour: Int, minute: Int) {
        viewModelScope.launch {
            preferencesRepository.setReminder(enabled, hour, minute)
            val context = getApplication<Application>()
            if (enabled) {
                ReminderScheduler.schedule(context, hour, minute)
            } else {
                ReminderScheduler.cancel(context)
            }
        }
    }

    fun setThemeMode(mode: ThemeMode) {
        viewModelScope.launch {
            preferencesRepository.setThemeMode(mode)
        }
    }

    /** Deletes all recorded goals/history/stats. Does not touch these settings. */
    fun resetAllData() {
        viewModelScope.launch {
            goalRepository.deleteAllGoals()
            _dataCleared.value = true
        }
    }

    fun onDataClearedAcknowledged() {
        _dataCleared.value = false
    }
}
