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
    
    // MARK: - Configuration
    private let baseURL = "https://maryland-trivia-contest.f22682jcz6.workers.dev"
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
        
        let url = URL(string: "\(baseURL)/api/rounds/current")!
        
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
        let url = URL(string: "\(baseURL)/api/rounds/\(id)")!
        
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
        completionTime: TimeInterval
    ) async throws -> ScoreSubmissionResponse {
        try await AppAttestManager.shared.ensureAuthenticated()

        let submission = ScoreSubmission(
            userId: userId,
            username: username,
            score: score,
            completionTime: completionTime
        )
        let bodyData = try JSONEncoder().encode(submission)

        func makeRequest() -> URLRequest {
            let url = URL(string: "\(baseURL)/api/rounds/\(roundId)/score")!
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
        let url = URL(string: "\(baseURL)/api/leaderboard/\(roundId)")!
        
        let (data, response) = try await SecureSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw ContestError.rateLimited(parseRetryAfter(from: httpResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        
        return try Self.decoder.decode(LeaderboardResponse.self, from: data)
    }
    
    /// Fetch statistics for a specific user across all rounds
    func fetchUserStats(userId: String) async throws -> UserStats {
        let url = URL(string: "\(baseURL)/api/user/\(userId)/stats")!
        
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
        let url = URL(string: "\(baseURL)/api/leaderboard/daily")!

        let (data, response) = try await SecureSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw ContestError.rateLimited(parseRetryAfter(from: httpResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }

        return try Self.decoder.decode(DailyLeaderboardResponse.self, from: data)
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if let seconds = TimeInterval(raw), seconds.isFinite {
            return max(0, seconds)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"

        guard let retryDate = formatter.date(from: raw) else { return nil }
        return max(0, retryDate.timeIntervalSinceNow)
    }

    /// Fetch recent round history for a user
    func fetchUserHistory(userId: String) async throws -> UserHistoryResponse {
        let url = URL(string: "\(baseURL)/api/user/\(userId)/history")!
        
        let (data, response) = try await SecureSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ContestError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ContestError.serverError(httpResponse.statusCode)
        }
        
        return try Self.decoder.decode(UserHistoryResponse.self, from: data)
    }
}

// MARK: - Models

/// Represents a contest round with synchronized questions
struct ContestRound: Codable, Identifiable {
    let id: String
    let startTime: Date
    let questionIds: [String]
    let status: RoundStatus
    
    enum RoundStatus: String, Codable {
        case scheduled, active, completed
    }
    
    enum CodingKeys: String, CodingKey {
        case id, startTime, questionIds, status
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // API returns timestamp in milliseconds
        let timestamp = try container.decode(Double.self, forKey: .startTime)
        startTime = Date(timeIntervalSince1970: timestamp / 1000)
        
        questionIds = try container.decode([String].self, forKey: .questionIds)
        status = try container.decode(RoundStatus.self, forKey: .status)
    }
}

/// Request body for submitting a score
struct ScoreSubmission: Codable {
    let userId: String
    let username: String
    let score: Int
    let completionTime: TimeInterval
}

/// Response after submitting a score
struct ScoreSubmissionResponse: Codable {
    let success: Bool
    let rank: Int
    let score: Int
}

/// Represents a leaderboard entry
struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let userId: String
    let username: String
    let score: Int
    let completionTime: TimeInterval
    let submittedAt: Date
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case rank, userId, username, score, completionTime, submittedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rank = try container.decode(Int.self, forKey: .rank)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        score = try container.decode(Int.self, forKey: .score)
        completionTime = try container.decode(TimeInterval.self, forKey: .completionTime)
        
        // API returns timestamp in milliseconds
        let timestamp = try container.decode(Double.self, forKey: .submittedAt)
        submittedAt = Date(timeIntervalSince1970: timestamp / 1000)
    }
}

/// Response containing leaderboard data
struct LeaderboardResponse: Codable {
    let roundId: String
    let entries: [LeaderboardEntry]
    let total: Int
}

/// User statistics across all contests
struct UserStats: Codable {
    let userId: String
    let totalRounds: Int
    let roundsCompleted: Int
    let avgScore: Int
    let bestScore: Int
    let worstScore: Int
    let bestRank: Int?
    let winStreak: Int?
}

/// Response containing user's round history
struct UserHistoryResponse: Codable {
    let userId: String
    let rounds: [UserRoundHistory]
}

/// A single round in user's history
struct UserRoundHistory: Codable, Identifiable {
    let roundId: String
    let score: Int
    let completionTime: Int
    let rank: Int
    let totalPlayers: Int
    let startTime: Date
    let submittedAt: Date
    
    var id: String { roundId }
    
    enum CodingKeys: String, CodingKey {
        case roundId, score, completionTime, rank, totalPlayers, startTime, submittedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roundId = try container.decode(String.self, forKey: .roundId)
        score = try container.decode(Int.self, forKey: .score)
        completionTime = try container.decode(Int.self, forKey: .completionTime)
        rank = try container.decode(Int.self, forKey: .rank)
        totalPlayers = try container.decode(Int.self, forKey: .totalPlayers)
        
        let startMs = try container.decode(Double.self, forKey: .startTime)
        startTime = Date(timeIntervalSince1970: startMs / 1000)
        
        let submittedMs = try container.decode(Double.self, forKey: .submittedAt)
        submittedAt = Date(timeIntervalSince1970: submittedMs / 1000)
    }
}

/// A daily leaderboard entry (aggregated across rounds in last 24 hours)
struct DailyLeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let userId: String
    let username: String
    let totalScore: Int
    let roundsPlayed: Int

    var id: String { userId }
}

/// Response containing daily leaderboard data
struct DailyLeaderboardResponse: Codable {
    let entries: [DailyLeaderboardEntry]
    let total: Int
}

// MARK: - Errors

enum ContestError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case rateLimited(TimeInterval?)
    case noRoundAvailable
    case submissionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Too many requests. Try again in \(Int(ceil(retryAfter)))s."
            }
            return "Too many requests. Please try again shortly."
        case .noRoundAvailable:
            return "No contest round available"
        case .submissionFailed:
            return "Failed to submit score"
        }
    }
}
