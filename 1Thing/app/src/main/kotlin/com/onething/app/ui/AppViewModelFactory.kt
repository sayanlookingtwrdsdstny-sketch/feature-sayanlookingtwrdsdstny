package com.onething.app.ui

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.onething.app.data.GoalRepository
import com.onething.app.data.UserPreferencesRepository

/** One factory for every screen's ViewModel — avoids repeating boilerplate per screen. */
class AppViewModelFactory(
    private val application: Application,
    private val goalRepository: GoalRepository,
    private val preferencesRepository: UserPreferencesRepository
) : ViewModelProvider.Factory {

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return when (modelClass) {
            TodayViewModel::class.java -> TodayViewModel(goalRepository)
            HistoryViewModel::class.java -> HistoryViewModel(goalRepository)
            StatsViewModel::class.java -> StatsViewModel(goalRepository)
            SettingsViewModel::class.java -> SettingsViewModel(
                application,
                preferencesRepository,
                goalRepository
            )
            else -> throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
        } as T
    }
}
