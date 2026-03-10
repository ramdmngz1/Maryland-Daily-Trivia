package com.copanostudios.marylanddailytrivia.core

/**
 * Scoring logic — exact port of iOS Scoring.swift.
 * All questions are worth up to MAX_POINTS.
 * Points decrease linearly from MAX_POINTS (instant) to 0 (timer expires).
 */
object Scoring {
    const val MAX_POINTS = 1000

    /**
     * Calculate points for an answer.
     * @param timeLimit Total time allowed (seconds), e.g. 12.0
     * @param secondsRemaining Time left when answer was given
     * @param isCorrect Whether the answer was correct
     * @return Points earned (0 for wrong answers)
     */
    fun points(timeLimit: Double, secondsRemaining: Double, isCorrect: Boolean): Int {
        if (!isCorrect) return 0
        val t = (secondsRemaining / timeLimit).coerceIn(0.0, 1.0)
        return (MAX_POINTS.toDouble() * t).toInt()
    }
}
