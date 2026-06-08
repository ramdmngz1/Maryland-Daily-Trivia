//
//  LiveTriviaView.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/19/26.
//  Updated: 4/19/26 - Question screen restyled to Maryland reference layout
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
    @State private var shareContent: ShareContent? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MarylandTriviaQuizBackground()

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
        .sheet(item: $shareContent) { content in
            ShareSheet(activityItems: [content.text])
        }
    }

    private func startSmoothTimer() {
        smoothTimer?.invalidate()
        smoothTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [self] _ in
            guard showJoinWait else { return }
            currentTime = Date()
            dismissJoinWaitIfNeeded()
        }
    }

    private func checkJoinWait() {
        guard let state = manager.liveState, !hasJoined else { return }
        let decisionTime = Date()
        currentTime = decisionTime

        // Ignore stale cached state from a previous app session/open.
        // We only decide join gating from an in-range round timeline.
        guard isFreshJoinDecisionState(state) else { return }

        // Compute phase directly from the state object rather than reading manager.localPhase /
        // manager.localQuestionIndex. Those published values are driven by the 50ms tick timer
        // and may not yet reflect the newly-arrived liveState when this method is called from
        // onChange(of: liveState.secondsRemaining), causing the join-wait to be skipped entirely.
        let (phase, questionIndex, _) = state.localState(at: decisionTime)

        let inQuiz = questionIndex >= 0 && questionIndex < 10
            && (phase == .question || phase == .explanation)

        guard inQuiz else {
            showJoinWait = false
            hasJoined = true
            return
        }

        // If it's the very first question (Q1), let the user join immediately —
        // there's no prior question to have missed and Q1 should always be playable.
        guard questionIndex > 0 else {
            showJoinWait = false
            hasJoined = true
            return
        }

        // If we're already on the last question (Q10), skip the overlay.
        guard questionIndex < 9 else {
            showJoinWait = false
            hasJoined = true
            return
        }

        // Next question starts at roundStartTime + (questionIndex + 1) * 22 seconds
        let nextQuestionStart = state.roundStartTime.addingTimeInterval(
            Double(questionIndex + 1) * LiveTriviaState.questionCycle
        )
        joinWaitTarget = nextQuestionStart
        joinWaitQuestionIndex = questionIndex + 1
        showJoinWait = nextQuestionStart.timeIntervalSince(decisionTime) > 0.15
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
        let questionNumber = max(1, min(10, manager.localQuestionIndex + 1))
        let score = manager.userSession?.totalScore ?? 0
        let phaseProgress = manager.localPhase == .question ? questionTimeFraction : 1
        let overallProgress = CGFloat(max(0.0, min(1.0, (Double(questionNumber - 1) + Double(phaseProgress)) / 10.0)))

        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Score:")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(score)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.18))
                    .monospacedDigit()

                Spacer()

                Text("Question \(questionNumber) / 10")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.62))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.90, blue: 0.30), Color(red: 1.0, green: 0.71, blue: 0.10)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * overallProgress)
                }
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.26), lineWidth: 1)
                )
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.black.opacity(0.5))
        .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Question View

    private var questionView: some View {
        GeometryReader { geo in
            if let question = manager.getCurrentQuestion() {
                let metrics = questionLayoutMetrics(
                    size: geo.size,
                    question: question.question,
                    answers: question.choices
                )

                VStack(spacing: metrics.stackSpacing) {
                    Spacer().frame(height: metrics.topPadding)

                    questionPromptCard(question.question, metrics: metrics)

                    VStack(spacing: metrics.answerSpacing) {
                        ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                            liveAnswerButton(text: choice, index: index, metrics: metrics)
                        }
                    }

                    inlineQuestionTimer(metrics: metrics)

                    Spacer(minLength: metrics.bottomPadding)
                }
                .padding(.horizontal, metrics.containerHorizontalPadding)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                Text("Loading question...")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func questionPromptCard(_ text: String, metrics: QuestionLayoutMetrics) -> some View {
        Text(text)
            .font(.system(size: metrics.questionFontSize, weight: .black, design: .rounded))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.50)
            .lineLimit(metrics.questionLineLimit)
            .foregroundStyle(Color(red: 0.18, green: 0.12, blue: 0.09))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, metrics.questionHorizontalPadding)
            .padding(.vertical, metrics.questionVerticalPadding)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.90, blue: 0.84), Color(red: 0.90, green: 0.85, blue: 0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: metrics.questionCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.questionCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.48), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.38), radius: 8, y: 3)
    }

    private func liveAnswerButton(
        text: String,
        index: Int,
        metrics: QuestionLayoutMetrics
    ) -> some View {
        let userAnswer = manager.userSession?.getAnswer(questionIndex: manager.localQuestionIndex)
        let isSelected = userAnswer?.selectedIndex == index
        let isEliminated = manager.eliminatedIndices.contains(index)
        let isJumping = jumpingAnswerIndex == index && isAnswerJumpActive
        let optionLetter = String(UnicodeScalar(65 + index) ?? "A")
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
            HStack(spacing: 12) {
                Text("\(optionLetter).")
                    .font(.system(size: metrics.answerLetterFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .white : Color(red: 1.0, green: 0.84, blue: 0.18))
                    .frame(width: metrics.answerLetterWidth, alignment: .leading)

                Text(text)
                    .font(.system(size: metrics.answerFontSize, weight: .black, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.55)
                    .lineLimit(metrics.answerLineLimit)
                    .foregroundStyle(.white.opacity(isEliminated ? 0.45 : 0.97))
                    .strikethrough(isEliminated, color: .white.opacity(0.42))

                Spacer(minLength: 6)

                if isEliminated {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: metrics.answerIndicatorSize, weight: .black))
                        .foregroundStyle(.white.opacity(0.45))
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: metrics.answerIndicatorSize, weight: .black))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .padding(.horizontal, metrics.answerHorizontalPadding)
            .padding(.vertical, metrics.answerVerticalPadding)
            .frame(minHeight: metrics.answerMinHeight)
            .background(answerFill(isSelected: isSelected, isEliminated: isEliminated), in: RoundedRectangle(cornerRadius: metrics.answerCornerRadius, style: .continuous))
            .scaleEffect(selectedScale * jumpScale)
            .offset(y: jumpOffsetY)
            .overlay(
                RoundedRectangle(cornerRadius: metrics.answerCornerRadius, style: .continuous)
                    .stroke(answerStroke(isSelected: isSelected, isEliminated: isEliminated), lineWidth: isSelected ? 2.3 : 1.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.answerCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.25 : 0.09), lineWidth: 0.8)
                    .padding(1.1)
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

    private func answerFill(isSelected: Bool, isEliminated: Bool) -> LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.74, blue: 0.18),
                    Color(red: 0.11, green: 0.53, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if isEliminated {
            return LinearGradient(
                colors: [Color.black.opacity(0.44), Color.black.opacity(0.56)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.26, green: 0.18, blue: 0.14),
                Color(red: 0.14, green: 0.10, blue: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func answerStroke(isSelected: Bool, isEliminated: Bool) -> Color {
        if isEliminated { return Color.white.opacity(0.06) }
        return isSelected ? Color(red: 0.56, green: 0.94, blue: 0.42) : Color.white.opacity(0.20)
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
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
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
                if let rank = manager.lastRoundRank {
                    VStack {
                        Text("#\(rank)")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(ColorTheme.accent)
                        Text("Rank")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTheme.textMuted)
                    }
                }
            }
            .padding(16)
            .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1))

            Button {
                shareContent = buildShareContent(
                    roundId: state.roundId,
                    totalScore: totalScore,
                    correctCount: correctCount,
                    answeredCount: answeredCount,
                    bestSpeed: bestSpeed
                )
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
                Text("Leaderboard in \(Int(ceil(manager.localSecondsRemaining)))s...")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTheme.textMuted)
            }
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .onAppear {
            animateRoundSummary(roundId: state.roundId, targetScore: totalScore)
        }
    }

    // MARK: - Leaderboard View

    private func leaderboardView(_ state: LiveTriviaState) -> some View {
        VStack(spacing: 0) {
            if state.nextRoundStartsIn != nil {
                Text("Next round in \(Int(ceil(manager.localSecondsRemaining)))s...")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ColorTheme.accent)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }

            // Daily leaderboard — combined scores across all rounds in the last 24 hours
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

    private func inlineQuestionTimer(metrics: QuestionLayoutMetrics) -> some View {
        let litSegments = max(
            0,
            min(
                metrics.timerSegmentCount,
                Int(ceil(questionTimeFraction * CGFloat(metrics.timerSegmentCount)))
            )
        )

        return HStack(spacing: metrics.timerGroupGap) {
            HStack(spacing: metrics.timerSegmentSpacing) {
                ForEach(0..<metrics.timerSegmentCount, id: \.self) { segment in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            segment < litSegments
                                ? LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.90, blue: 0.28), Color(red: 1.0, green: 0.72, blue: 0.11)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [Color.black.opacity(0.35), Color.black.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(width: metrics.timerSegmentWidth, height: metrics.timerSegmentHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.white.opacity(segment < litSegments ? 0.18 : 0.08), lineWidth: 0.7)
                        )
                }
            }
            .padding(.horizontal, metrics.timerInnerHorizontalPadding)
            .padding(.vertical, metrics.timerInnerVerticalPadding)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: metrics.timerInnerCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: metrics.timerInnerCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.17), lineWidth: 1)
            )

            Text("\(possibleQuestionPoints)")
                .font(.system(size: metrics.timerSecondsFontSize, weight: .black, design: .rounded))
                .monospacedDigit()
            .foregroundStyle(Color(red: 1.0, green: 0.88, blue: 0.21))
            .padding(.horizontal, metrics.timerInnerHorizontalPadding + 1)
            .padding(.vertical, metrics.timerInnerVerticalPadding - 1)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: metrics.timerInnerCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: metrics.timerInnerCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.17), lineWidth: 1)
            )
        }
        .padding(metrics.timerOuterPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: metrics.timerOuterCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.timerOuterCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Question points countdown and segment timer"))
        .accessibilityValue(Text("\(possibleQuestionPoints) points available"))
    }

    private func questionLayoutMetrics(
        size: CGSize,
        question: String,
        answers: [String]
    ) -> QuestionLayoutMetrics {
        computeQuestionLayoutMetrics(size: size, question: question, answers: answers)
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

    private func buildShareContent(
        roundId: String,
        totalScore: Int,
        correctCount: Int,
        answeredCount: Int,
        bestSpeed: String?
    ) -> ShareContent {
        let speedText = bestSpeed ?? "--"
        let summary = """
        I scored \(totalScore) points in Maryland Daily Trivia!
        ✅ \(correctCount)/\(answeredCount) correct
        ⚡️ Best speed: \(speedText)
        Round: \(roundId)
        """
        return ShareContent(text: summary)
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

#Preview {
    NavigationStack {
        LiveTriviaView()
    }
}
