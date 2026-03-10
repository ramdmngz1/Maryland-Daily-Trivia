//
//  LiveTriviaView.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/19/26.
//  Updated: 2/10/26 - Trivia theme redesign
//

import SwiftUI

struct LiveTriviaView: View {
    @StateObject private var manager = LiveTriviaManager.shared
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotionEnabled = false
    @AppStorage(AppPreferences.hasSeenLiveCoachMarksKey) private var hasSeenLiveCoachMarks = false

    @State private var currentTime = Date()
    @State private var smoothTimer: Timer?
    @State private var lastServerTime = Date()
    @State private var lastServerRemaining: Int = 12
    @State private var showJoinWait = false
    @State private var joinWaitTarget: Date? = nil
    @State private var joinWaitQuestionIndex: Int = -1
    @State private var hasJoined = false
    @State private var didTriggerQuestionUrgencyFeedback = false
    @State private var jumpingAnswerIndex: Int? = nil
    @State private var isAnswerJumpActive = false
    @State private var answerJumpSequence = 0
    @State private var showCoachMarks = false
    @State private var coachStepIndex = 0
    @State private var animatedRoundScore = 0
    @State private var animatedRoundID: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Top status bar
                if let state = manager.liveState {
                    statusBar(state)
                }

                if manager.error != nil, manager.liveState != nil, manager.isLocallyInQuiz {
                    reconnectBanner
                }

                // Main content — driven by locally-computed phase for smooth transitions
                if let state = manager.liveState {
                    if showJoinWait {
                        joinWaitView
                    } else if manager.isLocallyInQuiz {
                        if manager.localPhase == .question {
                            questionView
                                .id("question-\(manager.localQuestionIndex)")
                                .transition(phaseEntryTransition)
                        } else {
                            explanationView(state)
                                .id("explanation-\(manager.localQuestionIndex)")
                                .transition(phaseEntryTransition)
                        }
                    } else if manager.localPhase == .results {
                        resultsView(state)
                    } else {
                        leaderboardView(state)
                    }
                } else if let error = manager.error {
                    errorView(error)
                } else {
                    loadingView
                }

                // Banner ad
                BannerAdView(adUnitID: AdMobConfig.bannerAdUnitID)
                    .frame(height: 50)
                    .background(colorScheme == .dark ? ColorTheme.appSurface : ColorTheme.lightSurface)
            }

            if showCoachMarks {
                coachMarksOverlay
                    .transition(.opacity)
            }
        }
        .animation(phaseTransitionAnimation, value: manager.localPhase)
        .animation(phaseTransitionAnimation, value: manager.localQuestionIndex)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    smoothTimer?.invalidate()
                    manager.stopSync()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Exit")
                    }
                    .foregroundStyle(ColorTheme.accent)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("LIVE TRIVIA")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(ColorTheme.accent)
            }
        }
        .onAppear {
            manager.startSync()
            startSmoothTimer()
            if let state = manager.liveState {
                lastServerRemaining = state.secondsRemaining
                lastServerTime = Date()
            }
            checkJoinWait()
            presentCoachMarksIfNeeded()
        }
        .onDisappear {
            smoothTimer?.invalidate()
            manager.stopSync()
        }
        .onChange(of: manager.liveState?.secondsRemaining) { newValue in
            if let newValue = newValue {
                lastServerRemaining = newValue
                lastServerTime = Date()
            }
            checkJoinWait()
        }
        .onChange(of: manager.localQuestionIndex) { _ in
            // Reset interpolation on local question change
            lastServerRemaining = Int(ceil(manager.localSecondsRemaining))
            lastServerTime = Date()
            didTriggerQuestionUrgencyFeedback = false
            dismissJoinWaitIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                manager.startSync()
                startSmoothTimer()
                if let state = manager.liveState {
                    lastServerRemaining = state.secondsRemaining
                    lastServerTime = Date()
                }
                presentCoachMarksIfNeeded()
            } else {
                smoothTimer?.invalidate()
                smoothTimer = nil
            }
        }
        .onChange(of: manager.isLocallyInQuiz) { inQuiz in
            if inQuiz {
                presentCoachMarksIfNeeded()
            }
        }
        .onChange(of: manager.localPhase) { phase in
            if phase != .question {
                didTriggerQuestionUrgencyFeedback = false
            }
            dismissJoinWaitIfNeeded()
        }
        .onChange(of: questionIsUrgent) { isUrgent in
            if isUrgent && !didTriggerQuestionUrgencyFeedback {
                didTriggerQuestionUrgencyFeedback = true
                HapticManager.timeWarning()
            } else if !isUrgent {
                didTriggerQuestionUrgencyFeedback = false
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private func startSmoothTimer() {
        smoothTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            Task { @MainActor in
                currentTime = Date()
                dismissJoinWaitIfNeeded()
            }
        }
    }

    private func checkJoinWait() {
        guard let state = manager.liveState, !hasJoined else { return }

        // Ignore stale cached state from a previous app session/open.
        // We only decide join gating from an in-range round timeline.
        guard isFreshJoinDecisionState(state) else { return }

        guard manager.isLocallyInQuiz else {
            // Player is present before the quiz question phases start for this round.
            showJoinWait = false
            hasJoined = true
            return
        }

        // If we're already on the last question (Q10), don't show "first question in" overlay.
        guard manager.localQuestionIndex < 9 else {
            showJoinWait = false
            hasJoined = true
            return
        }

        guard manager.localPhase == .question || manager.localPhase == .explanation else {
            showJoinWait = false
            hasJoined = true
            return
        }

        // Next question starts at roundStartTime + (questionIndex + 1) * 22 seconds
        let nextQuestionStart = state.roundStartTime.addingTimeInterval(
            Double(manager.localQuestionIndex + 1) * LiveTriviaState.questionCycle
        )
        joinWaitTarget = nextQuestionStart
        joinWaitQuestionIndex = manager.localQuestionIndex + 1
        showJoinWait = nextQuestionStart.timeIntervalSince(currentTime) > 0.15
        if !showJoinWait {
            hasJoined = true
        }
    }

    private func dismissJoinWaitIfNeeded() {
        guard showJoinWait else { return }
        if !manager.isLocallyInQuiz {
            showJoinWait = false
            hasJoined = true
            return
        }

        if joinWaitRemaining <= 0.05,
           manager.localPhase == .question,
           manager.localQuestionIndex >= joinWaitQuestionIndex {
            showJoinWait = false
            hasJoined = true
        }
    }

    private func isFreshJoinDecisionState(_ state: LiveTriviaState) -> Bool {
        let elapsed = currentTime.timeIntervalSince(state.roundStartTime)
        return elapsed >= -1.0 && elapsed <= (LiveTriviaState.roundDuration + 5.0)
    }

    // MARK: - Status Bar

    private func statusBar(_ state: LiveTriviaState) -> some View {
        HStack {
            HStack(spacing: 6) {
                LiveDot()
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTheme.success)
                    .tracking(1)
            }

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("\(state.activePlayerCount)")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(ColorTheme.textMuted)

            Spacer()

            if manager.isLocallyInQuiz {
                Text("Q\(manager.localQuestionIndex + 1)/10")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(ColorTheme.accent)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(colorScheme == .dark ? ColorTheme.appSurface : ColorTheme.lightSurface)
    }

    // MARK: - Question View

    private var questionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let question = manager.getCurrentQuestion() {
                    // Category
                    CategoryPill(name: question.category.uppercased())
                        .padding(.top, 20)

                    // Question card
                    AppCard {
                        Text(question.question)
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                            .padding(20)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)

                    inlineQuestionTimer
                        .padding(.horizontal, 20)
                        .padding(.top, 2)

                    // Answers
                    VStack(spacing: 10) {
                        ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                            liveAnswerButton(
                                text: choice,
                                index: index
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text("Loading question...")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.textMuted)
                        .padding(.top, 40)
                }

                Spacer()
            }
        }
    }

    private func liveAnswerButton(
        text: String,
        index: Int
    ) -> some View {
        let userAnswer = manager.userSession?.getAnswer(questionIndex: manager.localQuestionIndex)
        let isSelected = userAnswer?.selectedIndex == index
        let isEliminated = manager.eliminatedIndices.contains(index)
        let isJumping = jumpingAnswerIndex == index && isAnswerJumpActive
        let defaultBackground = colorScheme == .dark ? ColorTheme.answerSandDark : ColorTheme.answerSand
        let selectedBackground = colorScheme == .dark ? ColorTheme.answerSandDarkSelected : ColorTheme.answerSandSelected
        let selectedScale: CGFloat = (isSelected && !shouldReduceMotion) ? 1.015 : 1.0
        let jumpScale: CGFloat = isJumping ? 1.05 : 1.0
        let jumpOffsetY: CGFloat = isJumping ? -10 : 0

        return Button {
            guard !isEliminated else { return }
            triggerAnswerJump(for: index)
            manager.recordAnswer(
                selectedIndex: index,
                timeRemaining: max(0, min(12, manager.localSecondsRemaining))
            )
        } label: {
            ZStack {
                Text(text)
                    .font(.system(size: 19, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                    .strikethrough(isEliminated, color: (colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)).opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 28)

                HStack {
                    Spacer()
                    if isEliminated {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ColorTheme.textMuted)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ColorTheme.accent)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(isSelected ? selectedBackground : defaultBackground)
            .scaleEffect(selectedScale * jumpScale)
            .offset(y: jumpOffsetY)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isEliminated ? .clear : (isSelected ? ColorTheme.accent : (colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(
            PressableCardButtonStyle(
                reduceMotion: shouldReduceMotion,
                isDisabled: isEliminated
            )
        )
        .disabled(isEliminated)
        .opacity(isEliminated ? 0.4 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .accessibilityValue(
            Text(
                isEliminated
                    ? "Eliminated"
                    : (isSelected ? "Selected" : "Not selected")
            )
        )
        .accessibilityHint(Text(isEliminated ? "This option is unavailable." : "Double tap to select this answer."))
        .animation(answerAnimation, value: isSelected)
        .animation(.easeInOut(duration: 0.3), value: isEliminated)
    }

    // MARK: - Explanation View

    private func explanationView(_ state: LiveTriviaState) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                if let question = manager.getCurrentQuestion(),
                   let userAnswer = manager.userSession?.getAnswer(questionIndex: manager.localQuestionIndex) {
                    let isCorrect = userAnswer.isCorrect

                    Spacer().frame(height: 20)

                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(isCorrect ? ColorTheme.success : ColorTheme.error)

                    Text(isCorrect ? "Correct!" : "Incorrect")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

                    if userAnswer.pointsEarned > 0 {
                        Text("+\(userAnswer.pointsEarned) points")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(ColorTheme.accent)
                    }

                    // Correct answer card
                    AppCard {
                        VStack(spacing: 8) {
                            Text("Correct Answer")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(ColorTheme.textMuted)

                            Text(question.choices[question.correctIndex])
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundStyle(ColorTheme.success)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)

                    if let explanation = question.explanation, !explanation.isEmpty {
                        Text(explanation)
                            .font(.system(size: 14))
                            .foregroundStyle(colorScheme == .dark ? ColorTheme.textSecondary : Color(red: 0.353, green: 0.29, blue: 0.212))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    nextQuestionCountdownCard
                        .padding(.horizontal, 24)

                    Spacer()
                } else {
                    // Time's up
                    VStack(spacing: 20) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(ColorTheme.warning)

                        Text("Time's Up!")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

                        if let question = manager.getCurrentQuestion() {
                            AppCard {
                                VStack(spacing: 8) {
                                    Text("Correct Answer")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(ColorTheme.textMuted)

                                    Text(question.choices[question.correctIndex])
                                        .font(.system(size: 16, weight: .semibold, design: .serif))
                                        .foregroundStyle(ColorTheme.success)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 24)
                        }

                        nextQuestionCountdownCard
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)
                }
            }
        }
    }

    // MARK: - Results View

    private func resultsView(_ state: LiveTriviaState) -> some View {
        let session = manager.userSession
        let totalScore = session?.totalScore ?? 0
        let answeredCount = session?.questionsAnswered ?? 0
        let correctCount = session?.correctCount ?? 0
        let bestSpeed = bestResponseTime(in: session)

        return VStack(spacing: 24) {
            Spacer()

            ArmadilloSpriteView(size: 128)

            NeonText(text: "ROUND COMPLETE", size: 20)

            VStack(spacing: 8) {
                Text("\(animatedRoundScore)")
                    .font(.system(size: 52, weight: .black, design: .serif))
                    .foregroundStyle(ColorTheme.accent)
                    .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.2) : .clear, radius: 10)

                Text("POINTS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            HStack(spacing: 30) {
                VStack {
                    Text("\(answeredCount)")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                    Text("Answered")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTheme.textMuted)
                }
                VStack {
                    Text("\(correctCount)")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(ColorTheme.success)
                    Text("Correct")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
            .padding(16)
            .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1))

            Button {
                prepareShareItems(
                    roundId: state.roundId,
                    totalScore: totalScore,
                    correctCount: correctCount,
                    answeredCount: answeredCount,
                    bestSpeed: bestSpeed
                )
                showShareSheet = true
                HapticManager.buttonTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Result")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(ColorTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ColorTheme.accent.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(ColorTheme.accent.opacity(0.45), lineWidth: 1))
            }

            Spacer()

            if let _ = state.nextRoundStartsIn {
                Text("Leaderboard in \(state.secondsRemaining)s...")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTheme.textMuted)
            }
        }
        .padding()
        .onAppear {
            animateRoundSummary(roundId: state.roundId, targetScore: totalScore)
        }
    }

    // MARK: - Leaderboard View

    private func leaderboardView(_ state: LiveTriviaState) -> some View {
        VStack(spacing: 0) {
            if let countdown = state.nextRoundStartsIn {
                Text("Next round in \(countdown)s...")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ColorTheme.accent)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }

            ContestLeaderboardView()
        }
    }

    // MARK: - Join Wait View

    /// Seconds remaining until next question, derived from smooth timer
    private var joinWaitRemaining: Double {
        guard let target = joinWaitTarget else { return 0 }
        return max(0, target.timeIntervalSince(currentTime))
    }

    /// Integer seconds for display (ceiling so "1" shows until 0.0)
    private var joinWaitDisplaySeconds: Int {
        Int(ceil(joinWaitRemaining))
    }

    private var joinWaitView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("FIRST QUESTION IN")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .tracking(2)
                .foregroundStyle(ColorTheme.textMuted)

            Text("\(joinWaitDisplaySeconds)")
                .id(joinWaitDisplaySeconds)
                .font(.system(size: 96, weight: .bold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(ColorTheme.accent)
                .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.3) : .clear, radius: 12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 1.14).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.48, dampingFraction: 0.86), value: joinWaitDisplaySeconds)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            Text("Connecting to live trivia...")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.7))
                    .frame(height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke((colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder).opacity(0.5), lineWidth: 1)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blendMode(.plusLighter)
                    )
                    .padding(.horizontal, 24)
                    .redacted(reason: .placeholder)
            }

            ProgressView()
                .scaleEffect(1.0)
                .tint(ColorTheme.accent)

            Text("Syncing questions and players...")
                .font(.system(size: 12))
                .foregroundStyle(ColorTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(ColorTheme.error.opacity(0.7))

            Text("Connection Error")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(ColorTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            GlowingButton("Retry") {
                Task { await manager.fetchLiveState() }
            }
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reconnectBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
            Text("Reconnecting to live game...")
                .font(.system(size: 12, weight: .semibold))
            ProgressView()
                .scaleEffect(0.75)
        }
        .foregroundStyle(ColorTheme.warning)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.95))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.warning.opacity(0.35), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "history": return ColorTheme.history
        case "geography": return ColorTheme.geography
        case "sports": return ColorTheme.sports
        case "culture": return ColorTheme.culture
        case "food": return ColorTheme.food
        default: return ColorTheme.accent
        }
    }

    private var inlineQuestionTimer: some View {
        ZStack {
            Circle()
                .stroke((colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder), lineWidth: 7)

            Circle()
                .trim(from: 0, to: questionTimeFraction)
                .stroke(
                    questionCountdownColor,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    shouldReduceMotion ? nil : .linear(duration: 0.12),
                    value: questionTimeFraction
                )

            Text("\(possibleQuestionPoints)")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(questionCountdownColor)
        }
        .frame(width: 82, height: 82)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Question timer"))
        .accessibilityValue(Text("\(Int(ceil(questionSecondsRemaining))) seconds left, \(possibleQuestionPoints) points possible"))
    }

    private var questionSecondsRemaining: Double {
        guard manager.localPhase == .question else { return 0 }
        return max(0, min(12, manager.localSecondsRemaining))
    }

    private var questionTimeFraction: CGFloat {
        CGFloat(max(0, min(1, questionSecondsRemaining / 12.0)))
    }

    private var possibleQuestionPoints: Int {
        if let answer = manager.userSession?.getAnswer(questionIndex: manager.localQuestionIndex) {
            return Scoring.points(timeLimit: 12, secondsRemaining: answer.timeRemaining, isCorrect: true)
        }
        return Scoring.points(timeLimit: 12, secondsRemaining: questionSecondsRemaining, isCorrect: true)
    }

    private var questionCountdownColor: Color {
        if questionSecondsRemaining <= 3 { return ColorTheme.timerRed }
        if questionSecondsRemaining <= 6 { return ColorTheme.timerOrange }
        return ColorTheme.accent
    }

    private var questionIsUrgent: Bool {
        manager.localPhase == .question && manager.isLocallyInQuiz && questionSecondsRemaining > 0 && questionSecondsRemaining <= 3
    }

    private var explanationSecondsRemaining: Double {
        guard manager.localPhase == .explanation else { return 0 }
        return max(0, min(LiveTriviaState.explanationTime, manager.localSecondsRemaining))
    }

    private var explanationTimerFraction: CGFloat {
        CGFloat(max(0, min(1, explanationSecondsRemaining / LiveTriviaState.explanationTime)))
    }

    private var explanationCountdownColor: Color {
        if explanationSecondsRemaining <= 3 { return ColorTheme.timerRed }
        if explanationSecondsRemaining <= 6 { return ColorTheme.timerOrange }
        return ColorTheme.accent
    }

    private var nextQuestionLabelText: String {
        manager.localQuestionIndex < 9 ? "NEXT QUESTION IN" : "ROUND RESULTS IN"
    }

    private var nextQuestionCountdownCard: some View {
        AppCard {
            VStack(spacing: 10) {
                Text(nextQuestionLabelText)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ColorTheme.textMuted)

                ZStack {
                    Circle()
                        .stroke((colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: explanationTimerFraction)
                        .stroke(
                            explanationCountdownColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            shouldReduceMotion ? nil : .linear(duration: 0.12),
                            value: explanationTimerFraction
                        )

                    Text("\(Int(ceil(explanationSecondsRemaining)))")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(explanationCountdownColor)
                }
                .frame(width: 64, height: 64)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(nextQuestionLabelText))
        .accessibilityValue(Text("\(Int(ceil(explanationSecondsRemaining))) seconds"))
    }

    private var shouldReduceMotion: Bool {
        reduceMotion || reduceMotionEnabled
    }

    private var coachSteps: [CoachStep] {
        [
            CoachStep(
                title: "Timer + Points",
                detail: "Watch the countdown and points available at the bottom. Faster answers earn more points.",
                icon: "timer"
            ),
            CoachStep(
                title: "Choose Quickly",
                detail: "Pick an answer card before time runs out. You can change your pick during the question window.",
                icon: "hand.tap.fill"
            ),
            CoachStep(
                title: "Round Flow",
                detail: "Each round has 10 questions, then results and leaderboard. A new round starts every few minutes.",
                icon: "repeat"
            )
        ]
    }

    private var coachMarksOverlay: some View {
        let step = coachSteps[min(coachStepIndex, max(0, coachSteps.count - 1))]

        return ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    HStack {
                        Label(step.title, systemImage: step.icon)
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundStyle(ColorTheme.accent)
                        Spacer()
                        Text("\(coachStepIndex + 1) / \(coachSteps.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Text(step.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        Button("Skip") {
                            finishCoachMarks()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTheme.textMuted)

                        Spacer()

                        Button(coachStepIndex == coachSteps.count - 1 ? "Got it" : "Next") {
                            if coachStepIndex == coachSteps.count - 1 {
                                finishCoachMarks()
                            } else {
                                withAnimation(answerAnimation ?? .easeInOut(duration: 0.2)) {
                                    coachStepIndex += 1
                                }
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [ColorTheme.accent, ColorTheme.neon],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
                .background((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke((colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
        }
        .onTapGesture {}
    }

    private func presentCoachMarksIfNeeded() {
        guard manager.isLocallyInQuiz,
              !showJoinWait,
              !hasSeenLiveCoachMarks,
              !showCoachMarks else { return }
        coachStepIndex = 0
        withAnimation(answerAnimation ?? .easeInOut(duration: 0.2)) {
            showCoachMarks = true
        }
    }

    private func finishCoachMarks() {
        hasSeenLiveCoachMarks = true
        withAnimation(answerAnimation ?? .easeInOut(duration: 0.2)) {
            showCoachMarks = false
        }
    }

    private func triggerAnswerJump(for index: Int) {
        guard !shouldReduceMotion else { return }
        answerJumpSequence += 1
        let sequence = answerJumpSequence
        jumpingAnswerIndex = index
        withAnimation(.interpolatingSpring(stiffness: 430, damping: 18)) {
            isAnswerJumpActive = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            guard sequence == answerJumpSequence else { return }
            withAnimation(.interpolatingSpring(stiffness: 340, damping: 24)) {
                isAnswerJumpActive = false
            }
        }
    }

    private func animateRoundSummary(roundId: String, targetScore: Int) {
        guard animatedRoundID != roundId else { return }
        animatedRoundID = roundId
        animatedRoundScore = 0

        let duration: Double = shouldReduceMotion ? 0.01 : 0.95
        let steps = max(1, min(36, targetScore == 0 ? 1 : targetScore / 60))
        let interval = duration / Double(steps)

        Task {
            for step in 1...steps {
                if Task.isCancelled { break }
                let value = Int((Double(targetScore) * Double(step) / Double(steps)).rounded())
                await MainActor.run {
                    animatedRoundScore = value
                }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            await MainActor.run {
                animatedRoundScore = targetScore
            }
        }
    }

    private func bestResponseTime(in session: UserAnswerSession?) -> String? {
        guard let session else { return nil }
        let fastest = session.answers.values
            .map { max(0, 12.0 - $0.timeRemaining) }
            .min()
        guard let fastest else { return nil }
        return String(format: "%.1fs", fastest)
    }

    private func prepareShareItems(
        roundId: String,
        totalScore: Int,
        correctCount: Int,
        answeredCount: Int,
        bestSpeed: String?
    ) {
        let speedText = bestSpeed ?? "--"
        let summary = """
        I scored \(totalScore) points in Maryland Daily Trivia!
        ✅ \(correctCount)/\(answeredCount) correct
        ⚡️ Best speed: \(speedText)
        Round: \(roundId)
        """
        shareItems = [summary]
    }

    private var phaseTransitionAnimation: Animation {
        shouldReduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.38, dampingFraction: 0.92, blendDuration: 0.1)
    }

    private var phaseEntryTransition: AnyTransition {
        shouldReduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .offset(x: 24, y: 0).combined(with: .opacity),
                removal: .offset(x: -20, y: 0).combined(with: .opacity)
            )
    }

    private var answerAnimation: Animation? {
        shouldReduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.9)
    }

}

private struct CoachStep {
    let title: String
    let detail: String
    let icon: String
}

// MARK: - Isolated Timer Section (own @State to avoid re-rendering parent)
private struct LiveTimerSection: View {
    let manager: LiveTriviaManager
    let lastServerTime: Date
    let lastServerRemaining: Int

    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotionEnabled = false
    @State private var currentTime = Date()
    @State private var smoothTimer: Timer?
    @State private var didTriggerUrgencyFeedback = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 6) {
            if manager.localPhase == .question {
                pointsDisplay
            }
            countdownDisplay
            timerBar
        }
        .onAppear { startTimer() }
        .onDisappear { smoothTimer?.invalidate() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { startTimer() } else { smoothTimer?.invalidate(); smoothTimer = nil }
        }
        .onChange(of: isUrgent) { urgent in
            if urgent && !didTriggerUrgencyFeedback {
                didTriggerUrgencyFeedback = true
                HapticManager.timeWarning()
            } else if !urgent {
                didTriggerUrgencyFeedback = false
            }
        }
    }

    private func startTimer() {
        smoothTimer?.invalidate()
        smoothTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private var smoothRemaining: Double {
        let total: Double = manager.localPhase == .question ? 12 : 10
        let elapsed = currentTime.timeIntervalSince(lastServerTime)
        return max(0, min(total, Double(lastServerRemaining) - elapsed))
    }

    private var pointsDisplay: some View {
        let userAnswer = manager.userSession?.getAnswer(questionIndex: manager.localQuestionIndex)
        let hasAnswered = userAnswer != nil
        let points: Int = {
            if let answer = userAnswer {
                return Scoring.points(timeLimit: 12, secondsRemaining: answer.timeRemaining, isCorrect: true)
            }
            return Scoring.points(timeLimit: 12, secondsRemaining: smoothRemaining, isCorrect: true)
        }()

        return HStack(spacing: 4) {
            Text("\(points)")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .monospacedDigit()
            Text("pts available")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(hasAnswered ? ColorTheme.accent : ColorTheme.textMuted)
        .animation(.easeInOut(duration: 0.2), value: hasAnswered)
    }

    private var countdownDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
            Text("\(Int(ceil(smoothRemaining)))s left")
                .monospacedDigit()
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(countdownColor)
        .scaleEffect(shouldReduceMotion ? 1.0 : urgencyPulseScale)
        .shadow(color: isUrgent ? countdownColor.opacity(0.22) : .clear, radius: isUrgent ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Time remaining"))
        .accessibilityValue(Text("\(Int(ceil(smoothRemaining))) seconds"))
    }

    private var timerBar: some View {
        let total: Double = manager.localPhase == .question ? 12 : 10
        let fraction = CGFloat(smoothRemaining / total)
        return LiveTimerBar(
            fraction: fraction,
            availableWidth: UIScreen.main.bounds.width - 40,
            colorScheme: colorScheme
        )
        .scaleEffect(x: 1.0, y: shouldReduceMotion ? 1.0 : urgencyBarScale)
        .shadow(color: isUrgent ? ColorTheme.timerRed.opacity(0.18) : .clear, radius: isUrgent ? 4 : 0)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Timer progress"))
        .accessibilityValue(Text("\(Int((fraction * 100).rounded())) percent remaining"))
    }

    private var countdownColor: Color {
        if smoothRemaining <= 3 { return ColorTheme.timerRed }
        if smoothRemaining <= 6 { return ColorTheme.timerOrange }
        return ColorTheme.accent
    }

    private var isUrgent: Bool {
        manager.localPhase == .question && smoothRemaining > 0 && smoothRemaining <= 3.0
    }

    private var urgencyPulseScale: CGFloat {
        guard isUrgent else { return 1.0 }
        let wave = (sin(currentTime.timeIntervalSinceReferenceDate * 7.0) + 1.0) * 0.5
        return 1.0 + CGFloat(wave * 0.045)
    }

    private var urgencyBarScale: CGFloat {
        guard isUrgent else { return 1.0 }
        let wave = (sin(currentTime.timeIntervalSinceReferenceDate * 7.0) + 1.0) * 0.5
        return 1.0 + CGFloat(wave * 0.026)
    }

    private var shouldReduceMotion: Bool {
        reduceMotion || reduceMotionEnabled
    }
}

private struct PressableCardButtonStyle: ButtonStyle {
    let reduceMotion: Bool
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressedScale: CGFloat = (configuration.isPressed && !reduceMotion && !isDisabled) ? 0.985 : 1.0
        return configuration.label
            .scaleEffect(pressedScale)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}

#Preview {
    NavigationStack {
        LiveTriviaView()
    }
}
