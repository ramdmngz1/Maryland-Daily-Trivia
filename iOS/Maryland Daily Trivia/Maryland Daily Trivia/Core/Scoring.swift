//
//  Scoring.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//
import Foundation

enum Scoring {

    /// All questions are worth up to 1000 points
    static let maxPoints = 1000

    /// Points based on speed.
    /// - Linearly decreases from 1000 (instant answer) to 0 (timer expires).
    /// - Wrong answer = 0.
    static func points(
        timeLimit: Double,
        secondsRemaining: Double,
        isCorrect: Bool
    ) -> Int {
        guard isCorrect else { return 0 }

        // Clamp ratio to 0...1
        let t = Swift.max(0.0, Swift.min(1.0, secondsRemaining / timeLimit))

        return Int((Double(maxPoints) * t).rounded(.down))
    }
}
