package com.onething.app.data

import java.time.LocalDate
import kotlin.math.roundToInt

/**
 * Basic, non-gamified stats derived from goal history.
 */
data class GoalStats(
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val totalCompleted: Int = 0,
    val completionPercentage: Int = 0
)

/**
 * Pure calculation from a list of [DailyGoal] (any order). No side effects, no auto-completion:
 * a day with no entry, or an entry that isn't completed, simply isn't counted — it is never
 * retroactively marked done.
 */
object GoalStatsCalculator {

    fun calculate(goals: List<DailyGoal>): GoalStats {
        // Only days where a goal was actually set count toward "attempted" totals.
        val attempted = goals.filter { it.goal.isNotBlank() }
        val completedDates = attempted.filter { it.completed }
            .mapNotNull { runCatching { LocalDate.parse(it.date) }.getOrNull() }
            .toSet()

        val totalCompleted = completedDates.size
        val completionPercentage = if (attempted.isEmpty()) {
            0
        } else {
            (totalCompleted * 100.0 / attempted.size).roundToInt()
        }

        return GoalStats(
            currentStreak = currentStreak(completedDates),
            longestStreak = longestStreak(completedDates),
            totalCompleted = totalCompleted,
            completionPercentage = completionPercentage
        )
    }

    /**
     * Consecutive completed days leading up to today. Today not yet being completed does NOT
     * break the streak (the day isn't over), it just doesn't extend it yet; any earlier gap does.
     */
    private fun currentStreak(completedDates: Set<LocalDate>): Int {
        var cursor = LocalDate.now()
        if (!completedDates.contains(cursor)) {
            cursor = cursor.minusDays(1)
        }
        var streak = 0
        while (completedDates.contains(cursor)) {
            streak++
            cursor = cursor.minusDays(1)
        }
        return streak
    }

    private fun longestStreak(completedDates: Set<LocalDate>): Int {
        if (completedDates.isEmpty()) return 0
        val sorted = completedDates.sorted()
        var longest = 1
        var run = 1
        for (i in 1 until sorted.size) {
            run = if (sorted[i] == sorted[i - 1].plusDays(1)) run + 1 else 1
            if (run > longest) longest = run
        }
        return longest
    }
}
