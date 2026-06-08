package com.copanostudios.marylanddailytrivia.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: — Round

@Serializable
enum class RoundStatus {
    @SerialName("scheduled") SCHEDULED,
    @SerialName("active") ACTIVE,
    @SerialName("completed") COMPLETED
}

@Serializable
data class ContestRound(
    val id: String,
    /** Milliseconds timestamp from server */
    val startTime: Double,
    val questionIds: List<String>,
    val status: RoundStatus
) {
    val startTimeMs: Long get() = startTime.toLong()
}

// MARK: — Score Submission

@Serializable
data class AnswerSubmission(
    val questionId: String,
    val selectedIndex: Int,
    val timeRemaining: Double,
    val isCorrect: Boolean
)

@Serializable
data class ScoreSubmission(
    val userId: String,
    val username: String,
    val score: Int,
    val completionTime: Double,
    val answers: List<AnswerSubmission> = emptyList()
)

@Serializable
data class ScoreSubmissionResponse(
    val success: Boolean,
    val rank: Int,
    val score: Int
)

// MARK: — Leaderboard

@Serializable
data class LeaderboardEntry(
    val rank: Int,
    val userId: String,
    val username: String,
    val score: Int,
    val completionTime: Double,
    /** Milliseconds timestamp from server */
    val submittedAt: Double
) {
    val submittedAtMs: Long get() = submittedAt.toLong()
}

@Serializable
data class LeaderboardResponse(
    val roundId: String,
    val entries: List<LeaderboardEntry>,
    val total: Int
)

// MARK: — Daily Leaderboard

@Serializable
data class DailyLeaderboardEntry(
    val rank: Int,
    val userId: String,
    val username: String,
    val totalScore: Int,
    val roundsPlayed: Int
)

@Serializable
data class DailyLeaderboardResponse(
    val entries: List<DailyLeaderboardEntry>,
    val total: Int
)

// MARK: — User Stats

@Serializable
data class UserStats(
    val userId: String,
    val totalRounds: Int,
    val roundsCompleted: Int,
    val avgScore: Int,
    val bestScore: Int,
    val worstScore: Int,
    val bestRank: Int? = null,
    val winStreak: Int? = null
)

// MARK: — Questions API

@Serializable
data class IdsRequest(val ids: List<String>)

@Serializable
data class QuestionsApiResponse(val questions: List<TriviaQuestion>)

// MARK: — Errors

class RateLimitedException(val retryAfterSeconds: Int) :
    Exception("Too many requests. Retry in ${retryAfterSeconds}s.")

