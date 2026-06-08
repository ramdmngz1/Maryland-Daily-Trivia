//
//  HapticManager.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/3/26.
//

import UIKit
import SwiftUI

/// Centralized haptic feedback manager for consistent tactile responses throughout the app
final class HapticManager {
    
    // MARK: - Singleton (optional, but convenient)
    static let shared = HapticManager()
    
    // MARK: - Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        // Pre-prepare generators for lower latency
        prepareAll()
    }
    
    // MARK: - Preparation
    /// Call this to prepare all generators (reduces latency on first use)
    func prepareAll() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    // MARK: - Impact Feedback
    /// General purpose impact feedback
    /// - Parameter style: The intensity of the impact
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard AppPreferences.hapticsEnabled else { return }
        switch style {
        case .light:
            shared.impactLight.impactOccurred()
            shared.impactLight.prepare()
        case .medium:
            shared.impactMedium.impactOccurred()
            shared.impactMedium.prepare()
        case .heavy:
            shared.impactHeavy.impactOccurred()
            shared.impactHeavy.prepare()
        case .soft:
            shared.impactSoft.impactOccurred()
            shared.impactSoft.prepare()
        case .rigid:
            shared.impactRigid.impactOccurred()
            shared.impactRigid.prepare()
        @unknown default:
            shared.impactMedium.impactOccurred()
            shared.impactMedium.prepare()
        }
    }
    
    // MARK: - Notification Feedback
    /// Used for task completion or state changes
    /// - Parameter type: Success, warning, or error
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AppPreferences.hapticsEnabled else { return }
        shared.notification.notificationOccurred(type)
        shared.notification.prepare()
    }
    
    // MARK: - Selection Feedback
    /// Lightweight feedback for selection changes (e.g., picker, segmented control)
    static func selection() {
        guard AppPreferences.hapticsEnabled else { return }
        shared.selection.selectionChanged()
        shared.selection.prepare()
    }
    
    // MARK: - Custom Patterns
    
    /// Double tap pattern (quick succession)
    static func doubleTap() {
        impact(style: .light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact(style: .light)
        }
    }
    
    /// Success pattern (light + medium)
    static func success() {
        impact(style: .light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            impact(style: .medium)
        }
    }
    
    /// Error pattern (heavy + rigid)
    static func error() {
        impact(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            impact(style: .rigid)
        }
    }
    
    /// Warning pattern (medium + light)
    static func warning() {
        impact(style: .medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact(style: .light)
        }
    }
    
    /// Celebration pattern (multiple light impacts)
    static func celebration() {
        let timings: [TimeInterval] = [0, 0.08, 0.16, 0.24]
        for (index, timing) in timings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + timing) {
                if index % 2 == 0 {
                    impact(style: .light)
                } else {
                    impact(style: .medium)
                }
            }
        }
    }
}

// MARK: - Quiz-Specific Haptic Helpers
extension HapticManager {
    
    /// Call when user selects an answer
    static func answerSelected() {
        selection()
        SoundFXManager.selection()
    }
    
    /// Call when answer is submitted
    static func answerSubmitted() {
        impact(style: .medium)
    }
    
    /// Call when answer is correct
    static func answerCorrect() {
        notification(type: .success)
        SoundFXManager.success()
    }
    
    /// Call when answer is incorrect
    static func answerIncorrect() {
        notification(type: .error)
        SoundFXManager.error()
    }
    
    /// Call when time is running out (< 3 seconds)
    static func timeWarning() {
        impact(style: .soft)
        SoundFXManager.warning()
    }
    
    /// Call when quiz is completed
    static func quizCompleted() {
        celebration()
    }
    
    /// Call when navigating to next question
    static func nextQuestion() {
        impact(style: .light)
    }
    
    /// Call when button is tapped
    static func buttonTap() {
        impact(style: .light)
        SoundFXManager.tap()
    }
    
    /// Call when score is submitted
    static func scoreSubmitted() {
        success()
    }
}

// MARK: - SwiftUI View Modifier
struct HapticFeedback: ViewModifier {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                HapticManager.impact(style: style)
            }
    }
}

extension View {
    /// Adds haptic feedback to any tappable view
    /// - Parameter style: The intensity of the haptic
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        modifier(HapticFeedback(style: style))
    }
}

// MARK: - Usage Examples & Integration Guide

/*
 
 USAGE EXAMPLES:
 
 1. Basic Impact:
 ```swift
 Button("Tap Me") {
     HapticManager.impact(style: .medium)
     // your action
 }
 ```
 
 2. Notification:
 ```swift
 func submitScore() {
     // ... submission logic
     if success {
         HapticManager.notification(type: .success)
     } else {
         HapticManager.notification(type: .error)
     }
 }
 ```
 
 3. Selection Change:
 ```swift
 Picker("Category", selection: $category) {
     // ...
 }
 .onChange(of: category) { _ in
     HapticManager.selection()
 }
 ```
 
 4. Quiz-Specific:
 ```swift
 // In QuizViewModel
 func selectAnswer(_ idx: Int) {
     guard submittedIndex == nil else { return }
     HapticManager.answerSelected()
     selectedIndex = idx
 }
 
 func submitSelected() {
     guard submittedIndex == nil else { return }
     HapticManager.answerSubmitted()
     submitAnswer(index: selectedIndex)
 }
 
 private func submitAnswer(index answerIndex: Int?) {
     let isCorrect = (answerIndex == currentQuestion.correctIndex)
     
     if isCorrect {
         HapticManager.answerCorrect()
     } else {
         HapticManager.answerIncorrect()
     }
     
     // ... rest of logic
 }
 
 func next() {
     HapticManager.nextQuestion()
     // ... navigation logic
 }
 
 private func finish() {
     stop()
     HapticManager.quizCompleted()
     isFinished = true
 }
 ```
 
 5. Timer Warning:
 ```swift
 private func tick() {
     guard isRunning else { return }
     guard submittedIndex == nil else { return }
     
     secondsRemaining = max(0, secondsRemaining - 0.1)
     
     // Warning haptic at 3 seconds
     if secondsRemaining <= 3.0 && secondsRemaining > 2.9 {
         HapticManager.timeWarning()
     }
     
     if secondsRemaining <= 0 {
         submitAnswer(index: nil)
     }
 }
 ```
 
 6. SwiftUI Modifier:
 ```swift
 Button("Tap Me") {
     // your action
 }
 .hapticFeedback(style: .light)
 ```
 
 7. Score Submission:
 ```swift
 func submitScore() {
     // ... submission logic
     gc.submit(score: totalScore, leaderboardIDs: ids) { error in
         if error == nil {
             HapticManager.scoreSubmitted()
         }
     }
 }
 ```
 
 INTEGRATION WITH YOUR EXISTING CODE:
 
 In QuizViewModel.swift, add these calls:
 
 - `selectAnswer()` → `HapticManager.answerSelected()`
 - `submitSelected()` → `HapticManager.answerSubmitted()`
 - After determining correct/incorrect → `HapticManager.answerCorrect()` or `HapticManager.answerIncorrect()`
 - `next()` → `HapticManager.nextQuestion()`
 - `finish()` → `HapticManager.quizCompleted()`
 - In `tick()` when < 3s → `HapticManager.timeWarning()`
 
 In ResultsView.swift:
 
 - After successful score submission → `HapticManager.scoreSubmitted()`
 
 In HomeView.swift:
 
 - On "Play Today" button → `HapticManager.buttonTap()`
 
 BEST PRACTICES:
 
 - Don't overuse haptics - they should enhance, not distract
 - Use lighter haptics for frequent actions
 - Use heavier haptics for important moments
 - Always prepare generators after use for next time
 - Test on actual device (haptics don't work in simulator)
 
 */
