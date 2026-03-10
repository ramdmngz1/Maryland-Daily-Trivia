package com.copanostudios.marylanddailytrivia.network

import com.copanostudios.marylanddailytrivia.core.AuthManager
import com.copanostudios.marylanddailytrivia.data.ContestRound
import com.copanostudios.marylanddailytrivia.data.DailyLeaderboardResponse
import com.copanostudios.marylanddailytrivia.data.LeaderboardResponse
import com.copanostudios.marylanddailytrivia.data.LiveTriviaState
import com.copanostudios.marylanddailytrivia.data.QuestionsApiResponse
import com.copanostudios.marylanddailytrivia.data.ScoreSubmission
import com.copanostudios.marylanddailytrivia.data.ScoreSubmissionResponse
import com.copanostudios.marylanddailytrivia.data.TriviaQuestion
import com.copanostudios.marylanddailytrivia.data.UserHistoryResponse
import com.copanostudios.marylanddailytrivia.data.UserStats
import com.copanostudios.marylanddailytrivia.data.IdsRequest
import com.copanostudios.marylanddailytrivia.data.RateLimitedException
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import retrofit2.HttpException
import retrofit2.Retrofit

/**
 * Singleton repository wrapping ApiService.
 * Handles 401 retry: catch, force-reauthenticate, retry once.
 */
class ContestRepository(
    private val authManager: AuthManager,
    private val apiService: ApiService
) {
    companion object {
        private val json = Json {
            ignoreUnknownKeys = true
            coerceInputValues = true
            isLenient = true
        }

        fun create(authManager: AuthManager): ContestRepository {
            val retrofit = Retrofit.Builder()
                .baseUrl("https://maryland-trivia-contest.f22682jcz6.workers.dev/")
                .client(SecureHttpClient.okHttpClient)
                .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
                .build()
            return ContestRepository(authManager, retrofit.create(ApiService::class.java))
        }
    }

    // MARK: — Public API (no auth required)

    suspend fun getLiveState(): LiveTriviaState = apiService.getLiveState()

    suspend fun getCurrentRound(): ContestRound = apiService.getCurrentRound()

    suspend fun getLeaderboard(roundId: String): LeaderboardResponse {
        return try {
            apiService.getLeaderboard(roundId)
        } catch (e: HttpException) {
            if (e.code() == 429) {
                val retryAfter = e.response()?.headers()?.get("Retry-After")?.toIntOrNull() ?: 3
                throw RateLimitedException(retryAfter)
            }
            throw e
        }
    }

    suspend fun getDailyLeaderboard(): DailyLeaderboardResponse {
        return try {
            apiService.getDailyLeaderboard()
        } catch (e: HttpException) {
            if (e.code() == 429) {
                val retryAfter = e.response()?.headers()?.get("Retry-After")?.toIntOrNull() ?: 3
                throw RateLimitedException(retryAfter)
            }
            throw e
        }
    }

    suspend fun getUserStats(userId: String): UserStats =
        apiService.getUserStats(userId)

    suspend fun getUserHistory(userId: String): UserHistoryResponse =
        apiService.getUserHistory(userId)

    // MARK: — Authenticated endpoints with 401 retry

    suspend fun submitScore(
        roundId: String,
        submission: ScoreSubmission
    ): ScoreSubmissionResponse {
        authManager.ensureAuthenticated()
        val token = authManager.getAccessToken()
        return try {
            apiService.submitScore(roundId, token?.let { "Bearer $it" }, submission)
        } catch (e: HttpException) {
            if (e.code() == 401) {
                authManager.forceReauthenticate()
                val newToken = authManager.getAccessToken()
                apiService.submitScore(roundId, newToken?.let { "Bearer $it" }, submission)
            } else throw e
        }
    }

    suspend fun getQuestions(ids: List<String>): List<TriviaQuestion> {
        authManager.ensureAuthenticated()
        val token = authManager.getAccessToken()
        return try {
            apiService.getQuestions(token?.let { "Bearer $it" }, IdsRequest(ids)).questions
        } catch (e: HttpException) {
            if (e.code() == 401) {
                authManager.forceReauthenticate()
                val newToken = authManager.getAccessToken()
                apiService.getQuestions(newToken?.let { "Bearer $it" }, IdsRequest(ids)).questions
            } else throw e
        }
    }
}
