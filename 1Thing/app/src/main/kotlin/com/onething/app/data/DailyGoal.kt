package com.onething.app.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.time.LocalDate

/**
 * One day's goal. [date] has a unique index so there can only ever be one goal per day —
 * that's the whole uniqueness rule; no separate "current goal" pointer is needed.
 */
@Entity(
    tableName = "daily_goals",
    indices = [Index(value = ["date"], unique = true)]
)
data class DailyGoal(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val date: String = LocalDate.now().toString(),
    val goal: String = "",
    val completed: Boolean = false,
    val completedAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    /** True if this day's goal was explicitly carried into the next day via "Move to tomorrow".
     *  The row is kept (not deleted) so the day still shows up in History instead of vanishing. */
    val movedToTomorrow: Boolean = false
)
