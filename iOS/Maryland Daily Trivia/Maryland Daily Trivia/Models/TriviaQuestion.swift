//
//  TriviaQuestion.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//
import Foundation

enum TriviaDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard
}

struct TriviaQuestion: Codable, Identifiable, Hashable {
    let id: String                  // stable unique id, e.g. "tx_hist_0001"
    let category: String            // "History", "Geography", "Sports", etc.
    let difficulty: TriviaDifficulty
    let question: String
    let choices: [String]           // 4 choices
    let correctIndex: Int           // 0...3
    let explanation: String?        // shown after answer (optional)

    // Optional metadata (safe to ignore in UI for now)
    let source: String?             // internal note / citation
    let tags: [String]?             // e.g. ["alamo", "san-antonio"]

    var isValid: Bool {
        choices.count == 4 &&
        (0..<choices.count).contains(correctIndex) &&
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
