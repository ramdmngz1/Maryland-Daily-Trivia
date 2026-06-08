//
//  AnswerPositionBalancer.swift
//  Maryland Daily Trivia
//
//  Shuffles answer choices per question and tries to balance
//  correctIndex positions across a set (A/B/C/D).
//
import Foundation

enum AnswerPositionBalancer {

    /// Returns questions where choices are shuffled and correctIndex updated,
    /// while trying to spread correct answers across positions 0...3.
    static func balancedShuffled(_ questions: [TriviaQuestion], seed: UInt64) -> [TriviaQuestion] {
        var rng = SeededGenerator(seed: seed)
        var slotCounts = Array(repeating: 0, count: 4)

        return questions.map { q in
            guard q.choices.count == 4, (0..<4).contains(q.correctIndex) else { return q }

            let correctAnswer = q.choices[q.correctIndex]

            var bestQuestion: TriviaQuestion? = nil
            var bestScore = Int.max

            // Try multiple shuffles and pick the one that best balances the set
            for _ in 0..<12 {
                var choices = q.choices
                choices.shuffle(using: &rng)

                guard let newCorrectIndex = choices.firstIndex(of: correctAnswer) else { continue }

                // Prefer the least-used slot so far
                let score = slotCounts[newCorrectIndex]
                if score < bestScore {
                    bestScore = score
                    bestQuestion = TriviaQuestion(
                        id: q.id,
                        category: q.category,
                        difficulty: q.difficulty,
                        question: q.question,
                        choices: choices,
                        correctIndex: newCorrectIndex,
                        explanation: q.explanation,
                        source: q.source,
                        tags: q.tags
                    )
                }
            }

            let final = bestQuestion ?? q
            slotCounts[final.correctIndex] += 1
            return final
        }
    }
}

/// Deterministic RNG so the same day gets the same shuffle.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = (seed == 0) ? 0xDEADBEEF : seed }

    mutating func next() -> UInt64 {
        // splitmix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
