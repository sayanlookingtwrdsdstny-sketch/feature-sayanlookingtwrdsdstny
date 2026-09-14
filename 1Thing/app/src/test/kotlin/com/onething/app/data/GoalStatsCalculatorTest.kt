package com.onething.app.data

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for [GoalStatsCalculator]. Pure function, no Android/Room dependency needed.
 */
class GoalStatsCalculatorTest {

    private fun goal(
        daysAgo: Long,
        text: String = "Do the thing",
        completed: Boolean = true
    ) = DailyGoal(
        date = LocalDate.now().minusDays(daysAgo).toString(),
        goal = text,
        completed = completed
    )

    @Test
    fun `empty list yields all-zero stats`() {
        val stats = GoalStatsCalculator.calculate(emptyList())
        assertEquals(GoalStats(), stats)
    }

    @Test
    fun `days with a blank goal are not attempted and do not count`() {
        val goals = listOf(
            goal(daysAgo = 0, text = "", completed = false),
            goal(daysAgo = 1, text = "   ", completed = true)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(0, stats.totalCompleted)
        assertEquals(0, stats.completionPercentage)
        assertEquals(0, stats.currentStreak)
    }

    @Test
    fun `completion percentage rounds to nearest whole percent`() {
        // 1 of 3 attempted completed -> 33.33% rounds to 33
        val goals = listOf(
            goal(daysAgo = 0, completed = true),
            goal(daysAgo = 1, completed = false),
            goal(daysAgo = 2, completed = false)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(1, stats.totalCompleted)
        assertEquals(33, stats.completionPercentage)
    }

    @Test
    fun `current streak counts consecutive completed days ending today`() {
        val goals = listOf(
            goal(daysAgo = 0, completed = true),
            goal(daysAgo = 1, completed = true),
            goal(daysAgo = 2, completed = true),
            goal(daysAgo = 3, completed = false) // breaks it
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(3, stats.currentStreak)
    }

    @Test
    fun `today not yet completed does not break an in-progress streak`() {
        // Today has no entry at all (not yet acted on); yesterday and the day before were completed.
        val goals = listOf(
            goal(daysAgo = 1, completed = true),
            goal(daysAgo = 2, completed = true)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(2, stats.currentStreak)
    }

    @Test
    fun `today explicitly not completed still counts streak from yesterday`() {
        val goals = listOf(
            goal(daysAgo = 0, completed = false),
            goal(daysAgo = 1, completed = true),
            goal(daysAgo = 2, completed = true)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(2, stats.currentStreak)
    }

    @Test
    fun `a gap before today resets the current streak to zero`() {
        val goals = listOf(
            goal(daysAgo = 2, completed = true),
            goal(daysAgo = 3, completed = true)
            // daysAgo 0 and 1 have no completed entry -> gap right before "today"
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(0, stats.currentStreak)
    }

    @Test
    fun `longest streak finds the best run even if it is not the current one`() {
        val goals = listOf(
            // Older 4-day run: daysAgo 10..7
            goal(daysAgo = 10, completed = true),
            goal(daysAgo = 9, completed = true),
            goal(daysAgo = 8, completed = true),
            goal(daysAgo = 7, completed = true),
            // gap
            goal(daysAgo = 5, completed = false),
            // Current shorter run: today + yesterday
            goal(daysAgo = 0, completed = true),
            goal(daysAgo = 1, completed = true)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(4, stats.longestStreak)
        assertEquals(2, stats.currentStreak)
    }

    @Test
    fun `duplicate dates are not double counted`() {
        val goals = listOf(
            goal(daysAgo = 0, completed = true),
            goal(daysAgo = 0, completed = true)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(1, stats.totalCompleted)
        assertEquals(1, stats.currentStreak)
    }

    @Test
    fun `unparseable dates are ignored rather than crashing`() {
        val goals = listOf(
            DailyGoal(date = "not-a-date", goal = "Broken", completed = true),
            goal(daysAgo = 0, completed = true)
        )
        val stats = GoalStatsCalculator.calculate(goals)
        assertEquals(1, stats.totalCompleted)
        assertEquals(1, stats.currentStreak)
    }
}
