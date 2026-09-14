package com.onething.app.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDate

class GoalRepository(private val goalDao: GoalDao) {
    fun getTodayGoal(): Flow<DailyGoal?> = goalDao.getGoalForDate(today())

    /**
     * Creates today's goal, or edits it in place if one is already set. Editing also clears
     * [DailyGoal.movedToTomorrow] — setting new text for today means today is active again,
     * not a stale record of a goal that got moved away.
     */
    suspend fun saveGoal(goalText: String) {
        val existing = goalDao.getGoalForDate(today()).first()
        val goal = existing?.copy(goal = goalText, movedToTomorrow = false)
            ?: DailyGoal(date = today(), goal = goalText)
        goalDao.upsertGoal(goal)
    }

    /** No-ops if [dailyGoal] is already completed, so a duplicate tap can never re-record it. */
    suspend fun completeGoal(dailyGoal: DailyGoal) {
        if (dailyGoal.completed) return
        goalDao.upsertGoal(
            dailyGoal.copy(
                completed = true,
                completedAt = System.currentTimeMillis()
            )
        )
    }

    /**
     * Explicitly carries an unfinished goal's text into tomorrow. Today's row is kept (marked
     * [DailyGoal.movedToTomorrow], not deleted) so it still shows up in History instead of
     * silently disappearing. Never happens automatically — the user has to choose it.
     */
    suspend fun moveGoalToTomorrow(dailyGoal: DailyGoal) {
        if (dailyGoal.completed || dailyGoal.goal.isBlank()) return
        val tomorrow = LocalDate.parse(dailyGoal.date).plusDays(1).toString()
        val existingTomorrow = goalDao.getGoalForDate(tomorrow).first()
        val movedGoal = existingTomorrow?.copy(goal = dailyGoal.goal)
            ?: DailyGoal(date = tomorrow, goal = dailyGoal.goal)
        goalDao.upsertGoal(movedGoal)
        goalDao.upsertGoal(dailyGoal.copy(movedToTomorrow = true))
    }

    /** Permanently removes a single day's goal (Today screen or a History entry). */
    suspend fun deleteGoal(dailyGoal: DailyGoal) {
        goalDao.deleteGoalForDate(dailyGoal.date)
    }

    /** Full history, newest first. */
    fun getAllGoals(): Flow<List<DailyGoal>> = goalDao.getAllGoals()

    /** Current streak, longest streak, total completed, completion %. */
    fun getStats(): Flow<GoalStats> = getAllGoals().map { GoalStatsCalculator.calculate(it) }

    /** Wipes all recorded goals. Used by Settings > Reset data. */
    suspend fun deleteAllGoals() {
        goalDao.deleteAll()
    }

    private fun today(): String = LocalDate.now().toString()
}
