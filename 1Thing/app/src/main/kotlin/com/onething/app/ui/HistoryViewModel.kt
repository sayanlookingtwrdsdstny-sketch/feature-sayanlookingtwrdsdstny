package com.onething.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.onething.app.data.DailyGoal
import com.onething.app.data.GoalRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class HistoryViewModel(private val repository: GoalRepository) : ViewModel() {
    private val _history = MutableStateFlow<List<DailyGoal>>(emptyList())
    val history: StateFlow<List<DailyGoal>> = _history.asStateFlow()

    init {
        viewModelScope.launch {
            repository.getAllGoals().collect { goals ->
                // Only show days a goal was actually set — an empty day isn't a "miss" to log.
                _history.value = goals.filter { it.goal.isNotBlank() }
            }
        }
    }

    fun deleteGoal(goal: DailyGoal) {
        viewModelScope.launch {
            repository.deleteGoal(goal)
        }
    }
}
