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
    /// Rank returned by the server after score submission for the most recent round.
    @Published private(set) var lastRoundRank: Int? = nil

    /// Locally-computed phase/question derived from roundStartTime + clock.
    /// Updated by the local tick timer. Views should prefer this
    /// over liveState.phase / liveState.currentQuestionIndex for smooth transitions.
    @Published private(set) var localPhase: LiveTriviaState.Phase = .question
    @Published private(set) var localQuestionIndex: Int = 0
    @Published private(set) var localSecondsRemaining: Double = 12

    // MARK: - Answer Elimination
    @Published private(set) var eliminatedIndices: Set<Int> = []
    private var eliminationQuestionIndex: Int = -1
    private var hasEliminatedFirst: Bool = false
    private var hasEliminatedSecond: Bool = false

    // MARK: - Configuration
    private static let decoder = JSONDecoder()
    private var syncTimer: Timer?
    private var localTickTimer: Timer?
    private let localTickInterval: TimeInterval = 0.1
    private let questionSyncInterval: TimeInterval = 1.0
    private let explanationSyncInterval: TimeInterval = 2.0
    private let postQuizSyncInterval: TimeInterval = 3.0
    private var currentSyncInterval: TimeInterval = 1.0
    private static let maxSyncInterval: TimeInterval = 30.0
    private var isBackingOff = false

    // Cache balanced questions keyed by round ID to avoid re-balancing on every sync
    private var cachedBalancedRoundId: String?
    private var lastStreakHapticQuestionIndex: Int = -1
    // Dedup: track which roundId has already had its score submitted
    private var submittedRoundId: String?

    // Scene phase observation for background/foreground
    private var didEnterBackgroundObserver: Any?
    private var willEnterForegroundObserver: Any?

    private init() {
        didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.stopSync() }
        }

        willEnterForegroundObserver = NotificationCenter.default.addObserver(
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
        if let observer = didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Start syncing with live trivia state
    func startSync() {
        guard syncTimer == nil else { return }
        currentSyncInterval = questionSyncInterval
        isBackingOff = false

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

        // Start local tick timer for smooth phase transitions
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
        syncTimer?.invalidate()
        syncTimer = nil
        localTickTimer?.invalidate()
        localTickTimer = nil
    }

    /// Local tick timer that computes phase/question locally from roundStartTime.
    private func startLocalTickTimer() {
        localTickTimer?.invalidate()
        // Timer fires on the main run loop (startLocalTickTimer is called from @MainActor context).
        // Using Task { @MainActor in } queues work asynchronously and can build up a backlog
        // during SwiftUI animation cycles, causing localQuestionIndex to lag behind real time.
        // This delay can prevent dismissJoinWaitIfNeeded() from releasing the gate at the Q9→Q10
        // boundary, causing Q10 to never show. DispatchQueue.main.async is FIFO and processes
        // promptly without actor scheduling overhead.
        localTickTimer = Timer.scheduledTimer(withTimeInterval: localTickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.updateLocalState()
            }
        }
    }

    private func updateLocalState() {
        guard let state = liveState else { return }
        let (phase, qIndex, remaining) = state.localState()
        let previousPhase = localPhase
        let previousIndex = localQuestionIndex

        if localPhase != phase {
            localPhase = phase
        }
        if localQuestionIndex != qIndex {
            localQuestionIndex = qIndex
        }
        if abs(localSecondsRemaining - remaining) >= localTickInterval || remaining <= 0 {
            localSecondsRemaining = remaining
        }

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
        let url = APIEnvironment.url(path: "api/live-state")

        do {
            let (data, response) = try await SecureSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw LiveStateFetchError.invalidResponse
            }
            let retryAfter = HTTPUtilities.retryAfter(from: http)
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

            // Restore a saved session if the user closed and reopened within the same round
            restoreSessionIfNeeded(for: newState.roundId)

            // Load questions for this round if needed (or retry if we got a partial set)
            if currentQuestions.isEmpty || roundChanged || currentQuestions.count < newState.questionIds.count {
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
            }
        }
    }

    private func desiredSyncInterval(for phase: LiveTriviaState.Phase) -> TimeInterval {
        switch phase {
        case .question:
            return questionSyncInterval
        case .explanation:
            return explanationSyncInterval
        case .results:
            return postQuizSyncInterval
        case .leaderboard:
            // Ramp up to fast polling in the final seconds of the leaderboard (and any time
            // after it expires) so the new round is detected within ~1s of it starting.
            // Without this, the 3-second poll cadence can leave Q1 with only ~9s on the clock.
            return localSecondsRemaining <= 5.0 ? questionSyncInterval : postQuizSyncInterval
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
        timeRemaining _: Double
    ) {
        guard let state = liveState,
              isLocallyInQuiz,
              localPhase == .question else {
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

        let exactLocalState = state.localState()
        let qIndex = exactLocalState.questionIndex
        guard exactLocalState.phase == .question,
              currentQuestions.indices.contains(qIndex) else { return }
        let question = currentQuestions[qIndex]
        let answerTimeRemaining = max(0, min(LiveTriviaState.questionTime, exactLocalState.secondsRemaining))

        // If selecting the same answer again, ignore
        if let existing = userSession?.getAnswer(questionIndex: qIndex),
           existing.selectedIndex == selectedIndex {
            return
        }

        // Calculate score based on current time remaining
        let isCorrect = selectedIndex == question.correctIndex
        let pointsEarned = Scoring.points(
            timeLimit: 12,
            secondsRemaining: answerTimeRemaining,
            isCorrect: isCorrect
        )

        // Record answer (UserAnswerSession handles subtracting old points)
        userSession?.recordAnswer(
            questionIndex: qIndex,
            questionId: question.id,
            selectedIndex: selectedIndex,
            isCorrect: isCorrect,
            pointsEarned: pointsEarned,
            timeRemaining: answerTimeRemaining
        )

        // Persist after every answer so a mid-round close can be recovered
        saveSession()

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
    }

    /// Submit final score to leaderboard
    func submitScore() async {
        guard let session = userSession,
              let state = liveState,
              session.questionsAnswered > 0 else {
            return
        }

        // Prevent duplicate submissions for the same round
        guard submittedRoundId != state.roundId else { return }

        let userId = getUserId()
        let username = getUsername()
        let completionTime = session.questionsAnswered * 22
        let answers: [AnswerSubmission] = session.answers
            .sorted { $0.key < $1.key }
            .map { _, ans in
                AnswerSubmission(
                    questionId: ans.questionId,
                    selectedIndex: ans.selectedIndex,
                    timeRemaining: ans.timeRemaining,
                    isCorrect: ans.isCorrect
                )
            }

        for attempt in 0..<3 {
            do {
                let response = try await ContestManager.shared.submitScore(
                    roundId: state.roundId,
                    userId: userId,
                    username: username,
                    score: session.totalScore,
                    completionTime: TimeInterval(completionTime),
                    answers: answers
                )
                submittedRoundId = state.roundId
                lastRoundRank = response.rank
                clearSavedSession()
                return
            } catch {
                #if DEBUG
                print("❌ Score submission attempt \(attempt + 1) failed: \(error)")
                #endif
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1)) * 1_000_000_000)
                }
            }
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
        // Reset for new round and discard any saved session from the previous round
        clearSavedSession()
        userSession = UserAnswerSession(roundId: newState.roundId)
        recentPointsAward = nil
        lastRoundRank = nil
        lastStreakHapticQuestionIndex = -1
        submittedRoundId = nil  // Allow submission for the new round
        resetEliminations()
    }

    // MARK: - Session persistence (survive app close/reopen within same round)

    private let savedSessionKey = "contest_saved_session"

    /// Persist the current session to UserDefaults after every answer.
    private func saveSession() {
        guard let session = userSession else { return }
        if let data = try? JSONEncoder().encode(session.snapshot()) {
            UserDefaults.standard.set(data, forKey: savedSessionKey)
        }
    }

    /// On app relaunch, restore answers if the saved round ID matches the current round.
    private func restoreSessionIfNeeded(for roundId: String) {
        guard userSession == nil || userSession?.roundId != roundId else { return }
        guard let data = UserDefaults.standard.data(forKey: savedSessionKey),
              let snapshot = try? JSONDecoder().decode(UserAnswerSession.Snapshot.self, from: data),
              snapshot.roundId == roundId,
              !snapshot.answers.isEmpty else { return }

        let session = UserAnswerSession(roundId: roundId)
        session.restore(from: snapshot)
        userSession = session
    }

    /// Discard a saved session (new round started or score successfully submitted).
    private func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: savedSessionKey)
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
        // Return cached result only if we have ALL questions for this round
        if cachedBalancedRoundId == state.roundId,
           currentQuestions.count >= state.questionIds.count { return }

        let seed = UInt64(state.roundStartTime.timeIntervalSince1970)

        #if targetEnvironment(simulator)
        // In simulator builds the AppAttest debug endpoint is disabled on the production server.
        // Use TriviaBank directly to avoid 403 errors and the resulting 1-second retry spam.
        let questionsById = Dictionary(uniqueKeysWithValues: TriviaBank.shared.questions.map { ($0.id, $0) })
        let orderedQuestions = state.questionIds.compactMap { questionsById[$0] }
        self.currentQuestions = AnswerPositionBalancer.balancedShuffled(orderedQuestions, seed: seed)
        cachedBalancedRoundId = state.roundId
        #else
        do {
            let questions = try await fetchQuestionsFromAPI(ids: state.questionIds)
            self.currentQuestions = AnswerPositionBalancer.balancedShuffled(questions, seed: seed)
            cachedBalancedRoundId = state.roundId
        } catch {
            // Fallback to TriviaBank — only cache if we found all questions
            let questionsById = Dictionary(uniqueKeysWithValues: TriviaBank.shared.questions.map { ($0.id, $0) })
            let orderedQuestions = state.questionIds.compactMap { questionsById[$0] }
            self.currentQuestions = AnswerPositionBalancer.balancedShuffled(orderedQuestions, seed: seed)
            if orderedQuestions.count >= state.questionIds.count {
                cachedBalancedRoundId = state.roundId
            }
            // If partial, leave cachedBalancedRoundId unset so the next sync retries
        }
        #endif
    }

    /// Fetch questions from API by IDs
    private func fetchQuestionsFromAPI(ids: [String]) async throws -> [TriviaQuestion] {
        try await AppAttestManager.shared.ensureAuthenticated()

        let bodyData = try JSONSerialization.data(withJSONObject: ["ids": ids])

        func makeRequest() -> URLRequest {
            let url = APIEnvironment.url(path: "api/questions")
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
        guard let result = try await group.next() else {
            group.cancelAll()
            throw CancellationError()
        }
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
