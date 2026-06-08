import Foundation

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
        let timestamp = try container.decode(Double.self, forKey: .startTime)
        startTime = Date(timeIntervalSince1970: timestamp / 1000)
        questionIds = try container.decode([String].self, forKey: .questionIds)
        status = try container.decode(RoundStatus.self, forKey: .status)
    }
}

struct AnswerSubmission: Codable {
    let questionId: String
    let selectedIndex: Int
    let timeRemaining: Double
    let isCorrect: Bool
}

struct ScoreSubmission: Codable {
    let userId: String
    let username: String
    let score: Int
    let completionTime: TimeInterval
    let answers: [AnswerSubmission]
}

struct ScoreSubmissionResponse: Codable {
    let success: Bool
    let rank: Int
    let score: Int
}

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
        let timestamp = try container.decode(Double.self, forKey: .submittedAt)
        submittedAt = Date(timeIntervalSince1970: timestamp / 1000)
    }
}

struct LeaderboardResponse: Codable {
    let roundId: String
    let entries: [LeaderboardEntry]
    let total: Int
}

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

struct DailyLeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let userId: String
    let username: String
    let totalScore: Int
    let roundsPlayed: Int

    var id: String { userId }
}

struct DailyLeaderboardResponse: Codable {
    let entries: [DailyLeaderboardEntry]
    let total: Int
}

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
