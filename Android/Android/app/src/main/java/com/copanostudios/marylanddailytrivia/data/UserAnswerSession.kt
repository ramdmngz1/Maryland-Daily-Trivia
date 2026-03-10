package com.copanostudios.marylanddailytrivia.data

/**
 * Immutable snapshot of a user's answers for the current round.
 * Functional-update pattern: all mutating operations return a new instance.
 */
data class UserAnswerSession(
    val roundId: String,
    val answers: Map<Int, UserAnswer> = emptyMap(),
    val totalScore: Int = 0,
    val questionsAnswered: Int = 0
) {
    data class UserAnswer(
        val questionId: String,
        val selectedIndex: Int,
        val isCorrect: Boolean,
        val pointsEarned: Int,
        val timeRemaining: Double
    )

    /** Record an answer, subtracting old points if changing a previous answer. */
    fun recordAnswer(
        questionIndex: Int,
        questionId: String,
        selectedIndex: Int,
        isCorrect: Boolean,
        pointsEarned: Int,
        timeRemaining: Double
    ): UserAnswerSession {
        val oldPoints = answers[questionIndex]?.pointsEarned ?: 0
        val newAnswers = answers + (questionIndex to UserAnswer(
            questionId = questionId,
            selectedIndex = selectedIndex,
            isCorrect = isCorrect,
            pointsEarned = pointsEarned,
            timeRemaining = timeRemaining
        ))
        return copy(
            answers = newAnswers,
            totalScore = totalScore - oldPoints + pointsEarned,
            questionsAnswered = newAnswers.size
        )
    }

    fun hasAnswered(questionIndex: Int): Boolean = answers.containsKey(questionIndex)

    fun getAnswer(questionIndex: Int): UserAnswer? = answers[questionIndex]

    /** Clear a recorded answer (e.g. when the selected answer is eliminated). */
    fun clearAnswer(questionIndex: Int): UserAnswerSession {
        val existing = answers[questionIndex] ?: return this
        val newAnswers = answers - questionIndex
        return copy(
            answers = newAnswers,
            totalScore = totalScore - existing.pointsEarned,
            questionsAnswered = newAnswers.size
        )
    }

    /** Reset for a new round. */
    fun reset(newRoundId: String) = UserAnswerSession(roundId = newRoundId)

    val correctCount: Int get() = answers.values.count { it.isCorrect }
}
