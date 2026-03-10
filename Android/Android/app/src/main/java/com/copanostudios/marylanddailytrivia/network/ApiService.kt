package com.copanostudios.marylanddailytrivia.network

import com.copanostudios.marylanddailytrivia.data.ContestRound
import com.copanostudios.marylanddailytrivia.data.DailyLeaderboardResponse
import com.copanostudios.marylanddailytrivia.data.IdsRequest
import com.copanostudios.marylanddailytrivia.data.LeaderboardResponse
import com.copanostudios.marylanddailytrivia.data.LiveTriviaState
import com.copanostudios.marylanddailytrivia.data.QuestionsApiResponse
import com.copanostudios.marylanddailytrivia.data.ScoreSubmission
import com.copanostudios.marylanddailytrivia.data.ScoreSubmissionResponse
import com.copanostudios.marylanddailytrivia.data.UserHistoryResponse
import com.copanostudios.marylanddailytrivia.data.UserStats
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path

interface ApiService {

    @GET("api/live-state")
    suspend fun getLiveState(): LiveTriviaState

    @GET("api/rounds/current")
    suspend fun getCurrentRound(): ContestRound

    /** Auth header required. Throws HttpException(401) if token invalid. */
    @POST("api/rounds/{roundId}/score")
    suspend fun submitScore(
        @Path("roundId") roundId: String,
        @Header("Authorization") authHeader: String?,
        @Body submission: ScoreSubmission
    ): ScoreSubmissionResponse

    @GET("api/leaderboard/{roundId}")
    suspend fun getLeaderboard(@Path("roundId") roundId: String): LeaderboardResponse

    @GET("api/leaderboard/daily")
    suspend fun getDailyLeaderboard(): DailyLeaderboardResponse

    @GET("api/user/{userId}/stats")
    suspend fun getUserStats(@Path("userId") userId: String): UserStats

    @GET("api/user/{userId}/history")
    suspend fun getUserHistory(@Path("userId") userId: String): UserHistoryResponse

    /** Auth header required. */
    @POST("api/questions")
    suspend fun getQuestions(
        @Header("Authorization") authHeader: String?,
        @Body request: IdsRequest
    ): QuestionsApiResponse

}
