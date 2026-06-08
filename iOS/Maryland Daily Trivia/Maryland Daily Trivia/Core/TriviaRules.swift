//
//  TriviaRules.swift
//  Maryland Daily Trivia
//

import Foundation

struct TriviaRule: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

enum TriviaRules {
    static let hasAcknowledgedKey = "has_acknowledged_rules_v1"
    static let pendingAcknowledgementKey = "pending_rules_acknowledgement_v1"

    static let items: [TriviaRule] = [
        TriviaRule(
            id: "questions-per-round",
            icon: "questionmark.circle.fill",
            title: "10 Questions Per Round",
            detail: "All players get the same questions at the same time. A new round starts every ~4 minutes."
        ),
        TriviaRule(
            id: "seconds-per-question",
            icon: "timer",
            title: "12 Seconds Per Question",
            detail: "Answer fast! You earn bonus points based on how quickly you respond."
        ),
        TriviaRule(
            id: "scoring",
            icon: "star.fill",
            title: "Scoring",
            detail: "Every question is worth up to 1,000 pts. Points decrease as the timer runs down. Answer fast for maximum points! Wrong answers score 0."
        ),
        TriviaRule(
            id: "leaderboard",
            icon: "trophy.fill",
            title: "Leaderboard",
            detail: "Your scores are totaled for the day. The leaderboard resets every 24 hours. Ties are broken by speed."
        ),
        TriviaRule(
            id: "play-anytime",
            icon: "bolt.fill",
            title: "Play Anytime",
            detail: "Rounds run continuously 24/7. Jump in whenever you want and compete against other players live."
        )
    ]
}
