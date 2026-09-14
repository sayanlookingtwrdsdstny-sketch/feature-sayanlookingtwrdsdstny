package com.onething.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.onething.app.data.DailyGoal
import com.onething.app.data.GoalRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TodayViewModel(private val repository: GoalRepository) : ViewModel() {
    private val _todayGoal = MutableStateFlow<DailyGoal?>(null)
    val todayGoal: StateFlow<DailyGoal?> = _todayGoal.asStateFlow()

    private val _streak = MutableStateFlow(0)
    val streak: StateFlow<Int> = _streak.asStateFlow()

    private val _showEditDialog = MutableStateFlow(false)
    val showEditDialog: StateFlow<Boolean> = _showEditDialog.asStateFlow()

    /** Pulses true right after a successful completion, for the one-shot success animation. */
    private val _justCompleted = MutableStateFlow(false)
    val justCompleted: StateFlow<Boolean> = _justCompleted.asStateFlow()

    init {
        viewModelScope.launch {
            repository.getTodayGoal().collect { goal ->
                _todayGoal.value = goal
            }
        }
        viewModelScope.launch {
            repository.getStats().collect { stats ->
                _streak.value = stats.currentStreak
            }
        }
    }

    fun openEditDialog() {
        _showEditDialog.value = true
    }

    fun closeEditDialog() {
        _showEditDialog.value = false
    }

    fun saveGoal(goalText: String) {
        viewModelScope.launch {
            repository.saveGoal(goalText)
            _showEditDialog.value = false
        }
    }

    fun completeGoal() {
        val goal = _todayGoal.value ?: return
        if (goal.completed) return // already done — ignore duplicate taps
        viewModelScope.launch {
            repository.completeGoal(goal)
            _justCompleted.value = true
        }
    }

    fun onCompletionAnimationShown() {
        _justCompleted.value = false
    }

    /**
     * Carries today's unfinished goal text into tomorrow. Today's entry is kept (marked
     * "moved") rather than cleared, so it still shows up in History — user-initiated only.
     */
    fun moveToTomorrow() {
        val goal = _todayGoal.value ?: return
        if (goal.completed) return
        viewModelScope.launch {
            repository.moveGoalToTomorrow(goal)
        }
    }

    /** Permanently removes today's goal (both active and already-moved entries). */
    fun deleteGoal() {
        val goal = _todayGoal.value ?: return
        viewModelScope.launch {
            repository.deleteGoal(goal)
        }
    }
}
