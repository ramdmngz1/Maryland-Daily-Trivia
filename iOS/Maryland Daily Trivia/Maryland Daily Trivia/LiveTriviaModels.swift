//
//  LiveTriviaModels.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/19/26.
//  Live Trivia System - AMI/Crowdpurr style
//

import Foundation
import Combine
import SwiftUI

// MARK: - Live State

/// Represents the current state of the global live trivia game
struct LiveTriviaState: Codable {
    let roundId: String
    let currentQuestionIndex: Int  // 0-9 for questions, -1 for results/leaderboard
    let phase: Phase
    let secondsRemaining: Int
    let questionIds: [String]
    let nextRoundStartsIn: Int?
    let activePlayerCount: Int
    let roundStartTime: Date
    
    enum Phase: String, Codable {
        case question
        case explanation
        case results
        case leaderboard
    }
    
    enum CodingKeys: String, CodingKey {
        case roundId, currentQuestionIndex, phase, secondsRemaining
        case questionIds, nextRoundStartsIn, activePlayerCount, roundStartTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roundId = try container.decode(String.self, forKey: .roundId)
        currentQuestionIndex = try container.decode(Int.self, forKey: .currentQuestionIndex)
        phase = try container.decode(Phase.self, forKey: .phase)
        secondsRemaining = try container.decode(Int.self, forKey: .secondsRemaining)
        questionIds = try container.decode([String].self, forKey: .questionIds)
        nextRoundStartsIn = try container.decodeIfPresent(Int.self, forKey: .nextRoundStartsIn)
        activePlayerCount = try container.decode(Int.self, forKey: .activePlayerCount)
        
        // roundStartTime comes as milliseconds timestamp
        let timestamp = try container.decode(Double.self, forKey: .roundStartTime)
        roundStartTime = Date(timeIntervalSince1970: timestamp / 1000)
    }
    
    /// Check if we're currently in the quiz phase (showing questions)
    var isInQuiz: Bool {
        return currentQuestionIndex >= 0 && currentQuestionIndex < 10
    }

    /// Check if showing results
    var isShowingResults: Bool {
        return phase == .results
    }

    /// Check if showing leaderboard
    var isShowingLeaderboard: Bool {
        return phase == .leaderboard
    }

    // MARK: - Timing Constants (must match server)
    static let questionTime: Double = 12
    static let explanationTime: Double = 10
    static let resultsTime: Double = 10
    static let leaderboardTime: Double = 20
    static let questionCycle: Double = questionTime + explanationTime  // 22s
    static let quizDuration: Double = questionCycle * 10              // 220s
    static let roundDuration: Double = quizDuration + resultsTime + leaderboardTime // 250s

    /// Compute current phase and question index locally from roundStartTime + now.
    /// Returns (phase, questionIndex, secondsRemaining).
    func localState(at now: Date = Date()) -> (phase: Phase, questionIndex: Int, secondsRemaining: Double) {
        let elapsed = now.timeIntervalSince(roundStartTime)

        if elapsed < Self.quizDuration {
            let questionIndex = Int(elapsed / Self.questionCycle)
            let timeInCycle = elapsed.truncatingRemainder(dividingBy: Self.questionCycle)
            if timeInCycle < Self.questionTime {
                return (.question, min(questionIndex, 9), Self.questionTime - timeInCycle)
            } else {
                return (.explanation, min(questionIndex, 9), Self.explanationTime - (timeInCycle - Self.questionTime))
            }
        } else if elapsed < Self.quizDuration + Self.resultsTime {
            return (.results, -1, Self.resultsTime - (elapsed - Self.quizDuration))
        } else {
            return (.leaderboard, -1, Self.leaderboardTime - (elapsed - Self.quizDuration - Self.resultsTime))
        }
    }
}

// MARK: - User Answer Tracking

/// Tracks user's answers for the current round
class UserAnswerSession: ObservableObject {
    @Published var roundId: String
    @Published var answers: [Int: UserAnswer] = [:]  // [questionIndex: answer]
    @Published var totalScore: Int = 0
    @Published var questionsAnswered: Int = 0
    
    struct UserAnswer {
        let questionId: String
        let selectedIndex: Int
        let isCorrect: Bool
        let pointsEarned: Int
        let timeRemaining: Double
    }
    
    init(roundId: String) {
        self.roundId = roundId
    }
    
    /// Record an answer for a question (allows changing answer)
    func recordAnswer(
        questionIndex: Int,
        questionId: String,
        selectedIndex: Int,
        isCorrect: Bool,
        pointsEarned: Int,
        timeRemaining: Double
    ) {
        // If changing an existing answer, subtract old points first
        if let existing = answers[questionIndex] {
            totalScore -= existing.pointsEarned
        }

        let answer = UserAnswer(
            questionId: questionId,
            selectedIndex: selectedIndex,
            isCorrect: isCorrect,
            pointsEarned: pointsEarned,
            timeRemaining: timeRemaining
        )

        answers[questionIndex] = answer
        totalScore += pointsEarned
        questionsAnswered = answers.count
    }
    
    /// Check if user has answered a specific question
    func hasAnswered(questionIndex: Int) -> Bool {
        return answers[questionIndex] != nil
    }
    
    /// Get user's answer for a question
    func getAnswer(questionIndex: Int) -> UserAnswer? {
        return answers[questionIndex]
    }

    /// Clear a recorded answer (e.g. when the selected answer is eliminated)
    func clearAnswer(questionIndex: Int) {
        if let existing = answers.removeValue(forKey: questionIndex) {
            totalScore -= existing.pointsEarned
            questionsAnswered = answers.count
        }
    }

    /// Reset for new round
    func reset(newRoundId: String) {
        self.roundId = newRoundId
        self.answers = [:]
        self.totalScore = 0
        self.questionsAnswered = 0
    }
    
    /// Get count of correct answers
    var correctCount: Int {
        return answers.values.filter { $0.isCorrect }.count
    }
}
