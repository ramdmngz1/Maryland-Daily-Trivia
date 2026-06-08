package com.copanostudios.marylanddailytrivia.core

data class EliminationState(
    val questionIndex: Int = -1,
    val eliminated: Set<Int> = emptySet(),
    val hasEliminatedFirst: Boolean = false,
    val hasEliminatedSecond: Boolean = false,
)

data class EliminationResult(
    val state: EliminationState,
    val shouldClearSelection: Boolean = false,
)

object AnswerElimination {
    private const val FIRST_THRESHOLD = 8.0
    private const val SECOND_THRESHOLD = 4.0

    fun update(
        current: EliminationState,
        questionIndex: Int,
        secondsRemaining: Double,
        correctIndex: Int,
        choiceCount: Int,
        currentSelection: Int?,
    ): EliminationResult {
        var state = if (questionIndex != current.questionIndex) {
            EliminationState(questionIndex = questionIndex)
        } else {
            current
        }

        var shouldClear = false

        if (secondsRemaining <= FIRST_THRESHOLD && !state.hasEliminatedFirst) {
            val victim = pickVictim(correctIndex, choiceCount, state.eliminated)
            if (victim != null) {
                shouldClear = currentSelection == victim
                state = state.copy(
                    eliminated = state.eliminated + victim,
                    hasEliminatedFirst = true,
                )
            }
        }

        if (secondsRemaining <= SECOND_THRESHOLD && !state.hasEliminatedSecond) {
            val victim = pickVictim(correctIndex, choiceCount, state.eliminated)
            if (victim != null) {
                shouldClear = shouldClear || currentSelection == victim
                state = state.copy(
                    eliminated = state.eliminated + victim,
                    hasEliminatedSecond = true,
                )
            }
        }

        return EliminationResult(state, shouldClear)
    }

    private fun pickVictim(correctIndex: Int, choiceCount: Int, eliminated: Set<Int>): Int? {
        return (0 until choiceCount)
            .filter { it != correctIndex && it !in eliminated }
            .randomOrNull()
    }
}
