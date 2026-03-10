package com.copanostudios.marylanddailytrivia.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class Phase {
    @SerialName("question") QUESTION,
    @SerialName("explanation") EXPLANATION,
    @SerialName("results") RESULTS,
    @SerialName("leaderboard") LEADERBOARD
}

/**
 * Represents the current state of the global live trivia game.
 * roundStartTime is received as milliseconds from the server.
 */
@Serializable
data class LiveTriviaState(
    val roundId: String,
    val currentQuestionIndex: Int,
    val phase: Phase,
    val secondsRemaining: Int,
    val questionIds: List<String>,
    val nextRoundStartsIn: Int? = null,
    val activePlayerCount: Int,
    /** Raw milliseconds timestamp from server */
    val roundStartTime: Double
) {
    /** Epoch milliseconds */
    val roundStartTimeMs: Long get() = roundStartTime.toLong()

    /** Epoch seconds as ULong — used as RNG seed for answer shuffling */
    val roundSeedULong: ULong get() = (roundStartTimeMs / 1000L).toULong()

    val isInQuiz: Boolean get() = currentQuestionIndex in 0 until 10

    val isShowingResults: Boolean get() = phase == Phase.RESULTS

    val isShowingLeaderboard: Boolean get() = phase == Phase.LEADERBOARD

    // MARK: — Timing constants (must match server)
    companion object {
        const val QUESTION_TIME: Double = 12.0
        const val EXPLANATION_TIME: Double = 10.0
        const val RESULTS_TIME: Double = 10.0
        const val LEADERBOARD_TIME: Double = 20.0
        const val QUESTION_CYCLE: Double = QUESTION_TIME + EXPLANATION_TIME  // 22s
        const val QUIZ_DURATION: Double = QUESTION_CYCLE * 10               // 220s
        const val ROUND_DURATION: Double = QUIZ_DURATION + RESULTS_TIME + LEADERBOARD_TIME // 250s
    }

    /**
     * Compute current phase and question index locally from roundStartTime + now.
     * Returns (phase, questionIndex, secondsRemaining).
     * Mirrors LiveTriviaState.localState() in iOS exactly.
     *
     * @param nowMs current time in epoch milliseconds (System.currentTimeMillis())
     */
    fun localState(nowMs: Long = System.currentTimeMillis()): Triple<Phase, Int, Double> {
        val elapsedSec = (nowMs - roundStartTimeMs) / 1000.0

        return when {
            elapsedSec < QUIZ_DURATION -> {
                val questionIndex = (elapsedSec / QUESTION_CYCLE).toInt()
                val timeInCycle = elapsedSec % QUESTION_CYCLE
                if (timeInCycle < QUESTION_TIME) {
                    Triple(Phase.QUESTION, minOf(questionIndex, 9), QUESTION_TIME - timeInCycle)
                } else {
                    Triple(
                        Phase.EXPLANATION,
                        minOf(questionIndex, 9),
                        EXPLANATION_TIME - (timeInCycle - QUESTION_TIME)
                    )
                }
            }
            elapsedSec < QUIZ_DURATION + RESULTS_TIME ->
                Triple(Phase.RESULTS, -1, RESULTS_TIME - (elapsedSec - QUIZ_DURATION))
            else ->
                Triple(
                    Phase.LEADERBOARD,
                    -1,
                    LEADERBOARD_TIME - (elapsedSec - QUIZ_DURATION - RESULTS_TIME)
                )
        }
    }
}
