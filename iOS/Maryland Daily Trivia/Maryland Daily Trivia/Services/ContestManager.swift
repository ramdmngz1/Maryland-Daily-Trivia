//
//  ContestManager.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/15/26.
//

import Foundation
import Combine

/// Manages all communication with the Maryland Trivia Contest API
@MainActor
final class ContestManager: ObservableObject {
    static let shared = ContestManager()
    
    private static let decoder = JSONDecoder()
    
    // MARK: - Published State
    @Published var currentRound: ContestRound?
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - API Methods
    
    /// Fetch the current active round
    func fetchCurrentRound() async throws -> ContestRound {
        isLoading = true
        defer { isLoading = false }
        
        let url = APIEnvironment.url(path: "api/rounds/current")
        
        let (data, response) = try await SecureSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        
        let round = try Self.decoder.decode(ContestRound.self, from: data)
        self.currentRound = round
        return round
    }
    
    /// Get a specific round by ID
    func fetchRound(id: String) async throws -> ContestRound {
        let url = APIEnvironment.url(path: "api/rounds/\(id)")
        
        let (data, response) = try await SecureSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        
        return try Self.decoder.decode(ContestRound.self, from: data)
    }
    
    /// Submit a user's score for a round
    func submitScore(
        roundId: String,
        userId: String,
        username: String,
        score: Int,
        completionTime: TimeInterval,
        answers: [AnswerSubmission] = []
    ) async throws -> ScoreSubmissionResponse {
        try await AppAttestManager.shared.ensureAuthenticated()

        let submission = ScoreSubmission(
            userId: userId,
            username: username,
            score: score,
            completionTime: completionTime,
            answers: answers
        )
        let bodyData = try JSONEncoder().encode(submission)

        func makeRequest() -> URLRequest {
            let url = APIEnvironment.url(path: "api/rounds/\(roundId)/score")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = AppAttestManager.shared.getAccessToken() {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            req.httpBody = bodyData
            return req
        }

        let (data, response) = try await SecureSession.shared.data(for: makeRequest())
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }

        // 401 retry: re-authenticate and try once more
        if httpResponse.statusCode == 401 {
            try await AppAttestManager.shared.forceReauthenticate()
            let (retryData, retryResp) = try await SecureSession.shared.data(for: makeRequest())
            guard let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                throw ContestError.serverError((retryResp as? HTTPURLResponse)?.statusCode ?? 0)
            }
            return try Self.decoder.decode(ScoreSubmissionResponse.self, from: retryData)
        }

        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        return try Self.decoder.decode(ScoreSubmissionResponse.self, from: data)
    }
    
    /// Fetch the leaderboard for a specific round
    func fetchLeaderboard(roundId: String) async throws -> LeaderboardResponse {
        let url = APIEnvironment.url(path: "api/leaderboard/\(roundId)")
        
        let (data, response) = try await SecureSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw ContestError.rateLimited(HTTPUtilities.retryAfter(from: httpResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        
        return try Self.decoder.decode(LeaderboardResponse.self, from: data)
    }
    
    /// Fetch statistics for a specific user across all rounds
    func fetchUserStats(userId: String) async throws -> UserStats {
        let url = APIEnvironment.url(path: "api/user/\(userId)/stats")
        
        let (data, response) = try await SecureSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        
        return try Self.decoder.decode(UserStats.self, from: data)
    }
    
    /// Fetch the daily leaderboard (top 10 by total score in last 24 hours)
    func fetchDailyLeaderboard() async throws -> DailyLeaderboardResponse {
        let url = APIEnvironment.url(path: "api/leaderboard/daily")

        let (data, response) = try await SecureSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw ContestError.rateLimited(HTTPUtilities.retryAfter(from: httpResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }

        return try Self.decoder.decode(DailyLeaderboardResponse.self, from: data)
    }

}
