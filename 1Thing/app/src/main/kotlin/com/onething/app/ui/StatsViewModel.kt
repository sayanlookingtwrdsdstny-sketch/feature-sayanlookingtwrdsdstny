package com.onething.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.onething.app.data.GoalRepository
import com.onething.app.data.GoalStats
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class StatsViewModel(repository: GoalRepository) : ViewModel() {
    private val _stats = MutableStateFlow(GoalStats())
    val stats: StateFlow<GoalStats> = _stats.asStateFlow()

    init {
        viewModelScope.launch {
            repository.getStats().collect { _stats.value = it }
        }
    }
}
