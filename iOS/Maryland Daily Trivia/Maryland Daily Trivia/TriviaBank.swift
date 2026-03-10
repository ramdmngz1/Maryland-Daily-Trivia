//
//  TriviaBank.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//
import Foundation
import UIKit

enum TriviaBankError: Error, LocalizedError {
    case missingFile(String)
    case decodeFailed(String)
    case invalidQuestion(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let name): return "Missing bundled JSON file: \(name)"
        case .decodeFailed(let msg): return "Failed to decode questions JSON: \(msg)"
        case .invalidQuestion(let id): return "Invalid question data for id: \(id)"
        }
    }
}

final class TriviaBank {
    static let shared = TriviaBank()

    private(set) var questions: [TriviaQuestion] = []

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.questions = []
        }
    }

    /// Loads questions from the app bundle. Call once at app start.
    func loadBundledQuestions(filename: String = "questions_md", ext: String = "json") throws {
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            throw TriviaBankError.missingFile("\(filename).\(ext)")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TriviaQuestion].self, from: data)

            for q in decoded {
                if !q.isValid { throw TriviaBankError.invalidQuestion(q.id) }
            }

            self.questions = decoded
        } catch {
            throw TriviaBankError.decodeFailed(error.localizedDescription)
        }
    }
}
