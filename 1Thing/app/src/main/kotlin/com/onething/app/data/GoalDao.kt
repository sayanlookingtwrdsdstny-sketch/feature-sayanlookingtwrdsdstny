package com.onething.app.data

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalDao {
    @Query("SELECT * FROM daily_goals WHERE date = :date LIMIT 1")
    fun getGoalForDate(date: String): Flow<DailyGoal?>

    /** Inserts a new goal, or updates the existing one if [goal].id already matches a row. */
    @Upsert
    suspend fun upsertGoal(goal: DailyGoal)

    @Query("DELETE FROM daily_goals WHERE date = :date")
    suspend fun deleteGoalForDate(date: String)

    /** All goals ever set, newest first. Backs history + stats (streaks, completion %). */
    @Query("SELECT * FROM daily_goals ORDER BY date DESC")
    fun getAllGoals(): Flow<List<DailyGoal>>

    @Query("DELETE FROM daily_goals")
    suspend fun deleteAll()
}
