//
//  LiveTriviaManager.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/19/26.
//  Manages synchronization with global live trivia state
//

import Foundation
import Combine
import SwiftUI

private enum LiveStateFetchError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String, TimeInterval?)
    case emptyBody(Int)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response for live state."
        case let .httpStatus(code, snippet, retryAfter):
            if let retryAfter {
                return "Live state HTTP \(code). Retry-After: \(Int(ceil(retryAfter)))s. \(snippet)"
            }
            return "Live state HTTP \(code). \(snippet)"
        case let .emptyBody(code):
            return "Live state HTTP \(code) returned an empty body."
        case let .decodeFailed(snippet):
            return "Live state payload decode failed. \(snippet)"
        }
    }
}

@MainActor
final class LiveTriviaManager: ObservableObject {
    static let shared = LiveTriviaManager()
    
    // MARK: - Published State
    @Published private(set) var liveState: LiveTriviaState?
    @Published private(set) var currentQuestions: [TriviaQuestion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var userSession: UserAnswerSession?
    @Published private(set) var recentPointsAward: PointsAwardEvent?

    /// Locally-computed phase/question derived from roundStartTime + clock.
    /// Updated every 50ms by the local tick timer. Views should prefer this
    /// over liveState.phase / liveState.currentQuestionIndex for smooth transitions.
    @Published private(set) var localPhase: LiveTriviaState.Phase = .question
    @Published private(set) var localQuestionIndex: Int = 0
    @Published private(set) var localSecondsRemaining: Double = 12

    // MARK: - Answer Elimination
    @Published private(set) var eliminatedIndices: Set<Int> = []
    private var eliminationQuestionIndex: Int = -1  // Track which question eliminations are for
    private var hasEliminatedFirst: Bool = false
    private var hasEliminatedSecond: Bool = false

    // MARK: - Configuration
    private let baseURL = "https://maryland-trivia-contest.f22682jcz6.workers.dev"
    private static let decoder = JSONDecoder()
    private var syncTimer: Timer?
    private var localTickTimer: Timer?
    private let questionSyncInterval: TimeInterval = 1.0
    private let explanationSyncInterval: TimeInterval = 2.0
    private let postQuizSyncInterval: TimeInterval = 3.0
    private var currentSyncInterval: TimeInterval = 1.0
    private static let maxSyncInterval: TimeInterval = 30.0
    private var isBackingOff = false

    // Cache balanced questions keyed by round ID to avoid re-balancing on every sync
    private var cachedBalancedRoundId: String?
    private var lastStreakHapticQuestionIndex: Int = -1

    // Scene phase observation for background/foreground
    private var scenePhaseObserver: Any?

    private init() {
        scenePhaseObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.stopSync() }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // Clear stale state so the UI shows a loading view rather than frozen data
                self.liveState = nil
                self.startSync()
            }
        }
    }

    nonisolated deinit {
        if let observer = scenePhaseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// Start syncing with live trivia state
    func startSync() {
        guard syncTimer == nil else { return }
        currentSyncInterval = questionSyncInterval
        isBackingOff = false

        #if DEBUG
        Swift.print("Starting live trivia sync (interval: \(currentSyncInterval)s)...")
        #endif

        // Load question bank if needed
        if TriviaBank.shared.questions.isEmpty {
            try? TriviaBank.shared.loadBundledQuestions()
        }

        // Initial fetch — cap auth to 5s so a stale token never blocks the UI indefinitely
        Task {
            try? await withTimeout(seconds: 5) {
                try await AppAttestManager.shared.ensureAuthenticated()
            }
            await fetchLiveState()
        }

        // Start polling timer
        scheduleSyncTimer()

        // Start local tick timer (50ms) for smooth phase transitions
        startLocalTickTimer()
    }

    private func scheduleSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: currentSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchLiveState()
            }
        }
    }
    
    /// Stop syncing
    func stopSync() {
        #if DEBUG
        Swift.print("Stopping live trivia sync")
        #endif
        syncTimer?.invalidate()
        syncTimer = nil
        localTickTimer?.invalidate()
        localTickTimer = nil
    }

    /// 50ms tick timer that computes phase/question locally from roundStartTime
    private func startLocalTickTimer() {
        localTickTimer?.invalidate()
        localTickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateLocalState()
            }
        }
    }

    private func updateLocalState() {
        guard let state = liveState else { return }
        let (phase, qIndex, remaining) = state.localState()
        let previousPhase = localPhase
        let previousIndex = localQuestionIndex

        localPhase = phase
        localQuestionIndex = qIndex
        localSecondsRemaining = remaining

        // Detect local transition into results phase → submit score
        if previousPhase != .results && phase == .results {
            Task { await submitScore() }
        }

        // Detect local question change → update eliminations
        if phase == .question && qIndex != previousIndex {
            resetEliminations()
        }

        // Drive answer eliminations from local timer
        if phase == .question {
            updateEliminationsLocally(questionIndex: qIndex, remaining: remaining)
        }

        adjustSyncIntervalForCurrentPhase()
    }
    
    /// Fetch current live state from API
    func fetchLiveState() async {
        let url = URL(string: "\(baseURL)/api/live-state")!
        
        do {
            let (data, response) = try await SecureSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw LiveStateFetchError.invalidResponse
            }
            let retryAfter = parseRetryAfter(from: http)
            guard (200...299).contains(http.statusCode) else {
                throw LiveStateFetchError.httpStatus(http.statusCode, responseSnippet(from: data), retryAfter)
            }
            guard !data.isEmpty else {
                throw LiveStateFetchError.emptyBody(http.statusCode)
            }

            let newState: LiveTriviaState
            do {
                newState = try Self.decoder.decode(LiveTriviaState.self, from: data)
            } catch {
                throw LiveStateFetchError.decodeFailed(responseSnippet(from: data))
            }
            
            // Check if round changed
            let roundChanged = liveState?.roundId != newState.roundId

            // Update state (local tick timer drives phase transitions)
            self.liveState = newState

            // Handle round change
            if roundChanged {
                handleRoundChange(newState)
            }

            // Load questions for this round if needed
            if currentQuestions.isEmpty || roundChanged {
                await loadQuestions(for: newState)
            }

            self.error = nil
            isBackingOff = false

            // Reset to phase-based sync cadence on success.
            let desired = desiredSyncInterval(for: localPhase)
            if currentSyncInterval != desired {
                currentSyncInterval = desired
                scheduleSyncTimer()
            }

        } catch {
            #if DEBUG
            Swift.print("Failed to fetch live state:", error.localizedDescription)
            #endif

            if case let LiveStateFetchError.httpStatus(code, _, retryAfter) = error, code == 429 {
                // Avoid noisy reconnect UI while we are intentionally waiting out rate limits.
                self.error = nil
                isBackingOff = true
                let fallbackRetry: TimeInterval = max(
                    desiredSyncInterval(for: localPhase),
                    min(currentSyncInterval * 2, Self.maxSyncInterval)
                )
                let wait = min(max(retryAfter ?? fallbackRetry, 1.0), Self.maxSyncInterval)
                if wait != currentSyncInterval {
                    currentSyncInterval = wait
                    scheduleSyncTimer()
                }
                #if DEBUG
                Swift.print("Rate limited (429): retrying live state in \(currentSyncInterval)s")
                #endif
                return
            }

            self.error = error
            isBackingOff = true

            // Keep retrying quickly for malformed/empty payloads; use backoff for transport/server failures.
            let maxBackoff: TimeInterval = shouldUseFastRetry(for: error) ? 2.0 : Self.maxSyncInterval
            let newInterval = min(currentSyncInterval * 2, maxBackoff)
            if newInterval != currentSyncInterval {
                currentSyncInterval = newInterval
                scheduleSyncTimer()
                #if DEBUG
                Swift.print("Backoff: sync interval now \(currentSyncInterval)s")
                #endif
            }
        }
    }

    private func desiredSyncInterval(for phase: LiveTriviaState.Phase) -> TimeInterval {
        switch phase {
        case .question:
            return questionSyncInterval
        case .explanation:
            return explanationSyncInterval
        case .results, .leaderboard:
            return postQuizSyncInterval
        }
    }

    private func adjustSyncIntervalForCurrentPhase() {
        guard !isBackingOff, syncTimer != nil else { return }
        let target = desiredSyncInterval(for: localPhase)
        guard target != currentSyncInterval else { return }
        currentSyncInterval = target
        scheduleSyncTimer()
    }
    
    /// Record user's answer for current question (allows changing selection)
    func recordAnswer(
        selectedIndex: Int,
        timeRemaining: Double
    ) {
        guard let state = liveState,
              isLocallyInQuiz,
              localPhase == .question,
              let question = getCurrentQuestion() else {
            #if DEBUG
            Swift.print("Cannot record answer - invalid state")
            #endif
            return
        }

        // Don't allow selecting eliminated answers
        guard !eliminatedIndices.contains(selectedIndex) else { return }

        // Ensure user session exists for this round
        if userSession == nil || userSession?.roundId != state.roundId {
            userSession = UserAnswerSession(roundId: state.roundId)
        }

        let qIndex = localQuestionIndex

        // If selecting the same answer again, ignore
        if let existing = userSession?.getAnswer(questionIndex: qIndex),
           existing.selectedIndex == selectedIndex {
            return
        }

        // Calculate score based on current time remaining
        let isCorrect = selectedIndex == question.correctIndex
        let pointsEarned = Scoring.points(
            timeLimit: 12,
            secondsRemaining: timeRemaining,
            isCorrect: isCorrect
        )

        // Record answer (UserAnswerSession handles subtracting old points)
        userSession?.recordAnswer(
            questionIndex: qIndex,
            questionId: question.id,
            selectedIndex: selectedIndex,
            isCorrect: isCorrect,
            pointsEarned: pointsEarned,
            timeRemaining: timeRemaining
        )

        if let session = userSession {
            let streak = currentCorrectStreak(in: session, through: qIndex)
            if isCorrect && pointsEarned > 0 {
                recentPointsAward = PointsAwardEvent(
                    questionIndex: qIndex,
                    points: pointsEarned,
                    streak: streak
                )
                if streak >= 2 && lastStreakHapticQuestionIndex != qIndex {
                    lastStreakHapticQuestionIndex = qIndex
                    HapticManager.impact(style: .rigid)
                }
            }
        }

        HapticManager.answerSelected()

        #if DEBUG
        Swift.print("Recorded answer for Q\(qIndex + 1): \(isCorrect ? "correct" : "wrong") +\(pointsEarned) pts")
        #endif
    }
    
    /// Submit final score to leaderboard
    func submitScore() async {
        guard let session = userSession,
              let state = liveState,
              session.questionsAnswered > 0 else {
            return
        }
        
        let userId = getUserId()
        let username = getUsername()
        
        #if DEBUG
        Swift.print("Submitting score: \(session.totalScore) pts (\(session.questionsAnswered)/10 questions)")
        #endif
        
        do {
            // Calculate completion time (full round or partial)
            let completionTime = session.questionsAnswered * 22  // 22 seconds per question (12s question + 10s explanation)
            
            let response = try await ContestManager.shared.submitScore(
                roundId: state.roundId,
                userId: userId,
                username: username,
                score: session.totalScore,
                completionTime: TimeInterval(completionTime)
            )
            
            #if DEBUG
            Swift.print("Score submitted! Rank: #\(response.rank)")
            #endif
            
        } catch {
            #if DEBUG
            Swift.print("Failed to submit score:", error.localizedDescription)
            #endif
        }
    }
    
    /// Get current question being shown (uses local timing)
    func getCurrentQuestion() -> TriviaQuestion? {
        guard liveState != nil,
              localQuestionIndex >= 0,
              localQuestionIndex < currentQuestions.count else {
            return nil
        }
        return currentQuestions[localQuestionIndex]
    }

    /// Check if user has answered current question
    func hasAnsweredCurrent() -> Bool {
        return userSession?.hasAnswered(questionIndex: localQuestionIndex) ?? false
    }

    /// Whether we're currently in the quiz portion (local timing)
    var isLocallyInQuiz: Bool {
        localQuestionIndex >= 0 && localQuestionIndex < 10
            && (localPhase == .question || localPhase == .explanation)
    }
    
    // MARK: - Private Methods
    
    private func handleRoundChange(_ newState: LiveTriviaState) {
        // Score submission happens during RESULTS phase, not here
        // Reset for new round
        userSession = UserAnswerSession(roundId: newState.roundId)
        recentPointsAward = nil
        lastStreakHapticQuestionIndex = -1
        resetEliminations()
    }

    /// Update answer eliminations based on locally-computed timer
    private func updateEliminationsLocally(questionIndex: Int, remaining: Double) {
        // Reset if we moved to a new question
        if questionIndex != eliminationQuestionIndex {
            resetEliminations()
            eliminationQuestionIndex = questionIndex
        }

        // 12s timer: 1/3 elapsed = 8s remaining, 2/3 elapsed = 4s remaining
        if remaining <= 8 && !hasEliminatedFirst {
            hasEliminatedFirst = true
            eliminateOneWrongAnswer(questionIndex: questionIndex)
        }

        if remaining <= 4 && !hasEliminatedSecond {
            hasEliminatedSecond = true
            eliminateOneWrongAnswer(questionIndex: questionIndex)
        }
    }

    /// Eliminate one random wrong answer
    private func eliminateOneWrongAnswer(questionIndex: Int) {
        guard let question = getCurrentQuestion() else { return }

        // Get user's current selection (if any)
        let currentSelection = userSession?.getAnswer(questionIndex: questionIndex)?.selectedIndex

        // Wrong answers that haven't been eliminated (including player's selection)
        let candidates = (0..<question.choices.count).filter { idx in
            idx != question.correctIndex && !eliminatedIndices.contains(idx)
        }

        guard let victim = candidates.randomElement() else { return }
        eliminatedIndices.insert(victim)

        // If the player's selected answer was eliminated, clear their recorded answer
        if currentSelection == victim {
            userSession?.clearAnswer(questionIndex: questionIndex)
        }
    }

    private func resetEliminations() {
        eliminatedIndices = []
        hasEliminatedFirst = false
        hasEliminatedSecond = false
        eliminationQuestionIndex = -1
    }
    
    private func loadQuestions(for state: LiveTriviaState) async {
        // Return cached result if already balanced for this round
        if cachedBalancedRoundId == state.roundId, !currentQuestions.isEmpty { return }

        do {
            let questions = try await fetchQuestionsFromAPI(ids: state.questionIds)
            let seed = UInt64(state.roundStartTime.timeIntervalSince1970)
            self.currentQuestions = AnswerPositionBalancer.balancedShuffled(questions, seed: seed)
        } catch {
            // Fallback to TriviaBank
            let allQuestions = TriviaBank.shared.questions
            let orderedQuestions = state.questionIds.compactMap { id in
                allQuestions.first { $0.id == id }
            }
            let seed = UInt64(state.roundStartTime.timeIntervalSince1970)
            self.currentQuestions = AnswerPositionBalancer.balancedShuffled(orderedQuestions, seed: seed)
        }
        cachedBalancedRoundId = state.roundId
    }
    
    /// Fetch questions from API by IDs
    private func fetchQuestionsFromAPI(ids: [String]) async throws -> [TriviaQuestion] {
        try await AppAttestManager.shared.ensureAuthenticated()

        let bodyData = try JSONSerialization.data(withJSONObject: ["ids": ids])

        func makeRequest() -> URLRequest {
            let url = URL(string: "\(baseURL)/api/questions")!
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
            throw NSError(domain: "LiveTrivia", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // 401 retry: re-authenticate and try once more
        if httpResponse.statusCode == 401 {
            try await AppAttestManager.shared.forceReauthenticate()
            let (retryData, retryResp) = try await SecureSession.shared.data(for: makeRequest())
            guard let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                throw NSError(domain: "LiveTrivia", code: (retryResp as? HTTPURLResponse)?.statusCode ?? 0,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \((retryResp as? HTTPURLResponse)?.statusCode ?? 0)"])
            }
            let apiResponse = try Self.decoder.decode(QuestionsAPIResponse.self, from: retryData)
            return apiResponse.questions
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "LiveTrivia", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }
        let apiResponse = try Self.decoder.decode(QuestionsAPIResponse.self, from: data)
        return apiResponse.questions
    }
    
    private func getUserId() -> String {
        KeychainHelper.getOrCreateUserId()
    }
    
    private func getUsername() -> String {
        let username = KeychainHelper.getOrCreateUsername()
        return username.isEmpty ? "Anonymous" : username
    }

    private func currentCorrectStreak(in session: UserAnswerSession, through questionIndex: Int) -> Int {
        guard questionIndex >= 0 else { return 0 }
        var streak = 0
        var idx = questionIndex
        while idx >= 0 {
            guard let answer = session.getAnswer(questionIndex: idx), answer.isCorrect else {
                break
            }
            streak += 1
            idx -= 1
        }
        return streak
    }

    private func responseSnippet(from data: Data, maxChars: Int = 180) -> String {
        guard !data.isEmpty else { return "Body: <empty>" }
        let text = String(decoding: data.prefix(512), as: UTF8.self)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "Body: <non-UTF8 \(data.count) bytes>" }
        let snippet = String(text.prefix(maxChars))
        return "Body: \(snippet)"
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        if let seconds = TimeInterval(raw), seconds >= 0 {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        if let date = formatter.date(from: raw) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    private func shouldUseFastRetry(for error: Error) -> Bool {
        if error is DecodingError { return true }
        if let fetchError = error as? LiveStateFetchError {
            switch fetchError {
            case .decodeFailed, .emptyBody:
                return true
            case let .httpStatus(code, _, _):
                return (500...599).contains(code)
            case .invalidResponse:
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - Helpers

private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - API Response Models

struct QuestionsAPIResponse: Codable {
    let questions: [TriviaQuestion]
}

struct PointsAwardEvent: Equatable, Identifiable {
    let id: UUID = UUID()
    let questionIndex: Int
    let points: Int
    let streak: Int
}
