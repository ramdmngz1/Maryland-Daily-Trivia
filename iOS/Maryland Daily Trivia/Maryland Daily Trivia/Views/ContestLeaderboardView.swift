import SwiftUI

struct ContestLeaderboardView: View {
    var roundId: String? = nil

    @StateObject private var manager = ContestManager.shared
    @State private var leaderboard: LeaderboardResponse?
    @State private var dailyLeaderboard: DailyLeaderboardResponse?
    @State private var currentLeaderboardEntry: LeaderboardEntry?
    @State private var currentDailyEntry: DailyLeaderboardEntry?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var userRank: Int?
    @State private var refreshTimer: Timer?
    @State private var retryCooldownSeconds = 0
    @State private var retryCooldownTimer: Timer?
    @State private var automaticRetryTask: Task<Void, Never>?
    @State private var autoScrollSignature = ""
    @Environment(\.colorScheme) var colorScheme

    private var isDaily: Bool { roundId == nil }

    var body: some View {
        ZStack {
            MarylandLeaderboardBackground()

            VStack(spacing: 0) {
                if isLoading && leaderboard == nil && dailyLeaderboard == nil {
                    AppLoadingStateView(
                        title: "Loading rankings",
                        message: "Fetching the latest Maryland trivia scores."
                    )
                } else if let error = error {
                    AppErrorStateView(
                        title: "Failed to load leaderboard",
                        message: error.localizedDescription,
                        retryCooldownSeconds: retryCooldownSeconds,
                        action: AppStateAction(
                            "Retry",
                            systemImage: "arrow.clockwise",
                            isEnabled: retryCooldownSeconds == 0
                        ) {
                            Task { await loadLeaderboard(force: true) }
                        }
                    )
                } else if isDaily, let daily = dailyLeaderboard {
                    dailyLeaderboardContent(daily)
                } else if let leaderboard = leaderboard {
                    leaderboardContent(leaderboard)
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .task {
            await loadLeaderboard()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
            stopRetryCooldown()
            automaticRetryTask?.cancel()
        }
    }

    // MARK: - Round Leaderboard

    private func leaderboardContent(_ data: LeaderboardResponse) -> some View {
        VStack(spacing: 12) {
            LeaderboardHeader(
                title: "LEADERBOARD",
                subtitle: "Today's Round \u{2022} \(data.total) \(data.total == 1 ? "Player" : "Players")",
                isLoading: isLoading
            )

            if let entry = currentLeaderboardEntry {
                LeaderboardRankPill(rank: entry.rank, scoreText: "\(entry.score) pts")
            }

            if data.entries.count >= 3 {
                HStack(alignment: .bottom, spacing: 8) {
                    LeaderboardPodiumColumn(
                        name: data.entries[1].username,
                        isCurrentUser: data.entries[1].userId == leaderboardCurrentUserId(),
                        rank: 2, height: 100,
                        scoreText: "\(data.entries[1].score)"
                    )
                    LeaderboardPodiumColumn(
                        name: data.entries[0].username,
                        isCurrentUser: data.entries[0].userId == leaderboardCurrentUserId(),
                        rank: 1, height: 120,
                        scoreText: "\(data.entries[0].score)"
                    )
                    LeaderboardPodiumColumn(
                        name: data.entries[2].username,
                        isCurrentUser: data.entries[2].userId == leaderboardCurrentUserId(),
                        rank: 3, height: 85,
                        scoreText: "\(data.entries[2].score)"
                    )
                }
            }

            if data.entries.isEmpty {
                AppEmptyStateView(
                    title: "No scores posted",
                    message: "This round is waiting for its first completed score."
                )
            } else {
                ScrollViewReader { proxy in
                    LeaderboardListContainer {
                        ForEach(data.entries) { entry in
                            LeaderboardRow(
                                rank: entry.rank,
                                username: entry.username,
                                isCurrentUser: entry.userId == leaderboardCurrentUserId(),
                                scoreText: "\(entry.score)"
                            )
                            .id(entry.userId)
                        }
                    }
                    .onAppear {
                        autoScrollToCurrentUser(in: data, proxy: proxy)
                    }
                    .onChange(of: data.entries.map(\.userId)) { _ in
                        autoScrollToCurrentUser(in: data, proxy: proxy)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Daily Leaderboard

    private func dailyLeaderboardContent(_ data: DailyLeaderboardResponse) -> some View {
        VStack(spacing: 12) {
            LeaderboardHeader(
                title: "LEADERBOARD",
                subtitle: "Today's Total \u{2022} \(data.total) \(data.total == 1 ? "Player" : "Players")",
                isLoading: isLoading
            )

            if let entry = currentDailyEntry {
                LeaderboardRankPill(rank: entry.rank, scoreText: "\(entry.totalScore) pts")
            }

            if data.entries.count >= 3 {
                HStack(alignment: .bottom, spacing: 8) {
                    LeaderboardPodiumColumn(
                        name: data.entries[1].username,
                        isCurrentUser: data.entries[1].userId == leaderboardCurrentUserId(),
                        rank: 2, height: 100,
                        scoreText: "\(data.entries[1].totalScore)",
                        subtitle: "\(data.entries[1].roundsPlayed) \(data.entries[1].roundsPlayed == 1 ? "round" : "rounds")"
                    )
                    LeaderboardPodiumColumn(
                        name: data.entries[0].username,
                        isCurrentUser: data.entries[0].userId == leaderboardCurrentUserId(),
                        rank: 1, height: 120,
                        scoreText: "\(data.entries[0].totalScore)",
                        subtitle: "\(data.entries[0].roundsPlayed) \(data.entries[0].roundsPlayed == 1 ? "round" : "rounds")"
                    )
                    LeaderboardPodiumColumn(
                        name: data.entries[2].username,
                        isCurrentUser: data.entries[2].userId == leaderboardCurrentUserId(),
                        rank: 3, height: 85,
                        scoreText: "\(data.entries[2].totalScore)",
                        subtitle: "\(data.entries[2].roundsPlayed) \(data.entries[2].roundsPlayed == 1 ? "round" : "rounds")"
                    )
                }
            }

            if data.entries.isEmpty {
                AppEmptyStateView(
                    title: "No rankings yet",
                    message: "Scores will appear here after players finish a round."
                )
            } else {
                ScrollViewReader { proxy in
                    LeaderboardListContainer {
                        ForEach(data.entries) { entry in
                            LeaderboardRow(
                                rank: entry.rank,
                                username: entry.username,
                                isCurrentUser: entry.userId == leaderboardCurrentUserId(),
                                scoreText: "\(entry.totalScore)",
                                subtitle: "\(entry.roundsPlayed) round\(entry.roundsPlayed == 1 ? "" : "s")"
                            )
                            .id(entry.userId)
                        }
                    }
                    .onAppear {
                        autoScrollToCurrentDailyUser(in: data, proxy: proxy)
                    }
                    .onChange(of: data.entries.map(\.userId)) { _ in
                        autoScrollToCurrentDailyUser(in: data, proxy: proxy)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Data Loading

    private func loadLeaderboard(force: Bool = false) async {
        guard !isLoading else { return }
        if !force && retryCooldownSeconds > 0 { return }

        isLoading = true
        error = nil
        do {
            if let roundId = roundId {
                let data = try await manager.fetchLeaderboard(roundId: roundId)
                leaderboard = data
                let userId = leaderboardCurrentUserId()
                if let entry = data.entries.first(where: { $0.userId == userId }) {
                    userRank = entry.rank
                    currentLeaderboardEntry = entry
                }
            } else {
                let data = try await manager.fetchDailyLeaderboard()
                dailyLeaderboard = data
                let userId = leaderboardCurrentUserId()
                if let entry = data.entries.first(where: { $0.userId == userId }) {
                    userRank = entry.rank
                    currentDailyEntry = entry
                }
            }
            clearRateLimitBackoff()
        } catch {
            self.error = error
            if case let ContestError.rateLimited(retryAfter) = error {
                applyRateLimitBackoff(retryAfter: retryAfter)
            }
        }
        isLoading = false
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        let interval: TimeInterval = roundId != nil ? 5.0 : 30.0
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak refreshTimer] _ in
            guard refreshTimer?.isValid == true else { return }
            Task { await loadLeaderboard() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func applyRateLimitBackoff(retryAfter: TimeInterval?) {
        let seconds = max(1, Int(ceil(retryAfter ?? 3)))
        startRetryCooldown(seconds: seconds)
        scheduleAutomaticRetry(after: seconds)
    }

    private func clearRateLimitBackoff() {
        stopRetryCooldown()
        automaticRetryTask?.cancel()
        automaticRetryTask = nil
    }

    private func startRetryCooldown(seconds: Int) {
        retryCooldownTimer?.invalidate()
        retryCooldownSeconds = seconds

        retryCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if retryCooldownSeconds <= 1 {
                stopRetryCooldown()
            } else {
                retryCooldownSeconds -= 1
            }
        }
    }

    private func stopRetryCooldown() {
        retryCooldownTimer?.invalidate()
        retryCooldownTimer = nil
        retryCooldownSeconds = 0
    }

    private func scheduleAutomaticRetry(after seconds: Int) {
        automaticRetryTask?.cancel()
        automaticRetryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await loadLeaderboard(force: true)
        }
    }

    private func autoScrollToCurrentUser(in data: LeaderboardResponse, proxy: ScrollViewProxy) {
        guard let entry = currentLeaderboardEntry else { return }
        let signature = "\(data.roundId)-\(data.total)-\(entry.userId)-\(entry.rank)"
        guard signature != autoScrollSignature else { return }
        autoScrollSignature = signature
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(entry.userId, anchor: .center)
            }
        }
    }

    private func autoScrollToCurrentDailyUser(in data: DailyLeaderboardResponse, proxy: ScrollViewProxy) {
        guard let entry = currentDailyEntry else { return }
        let signature = "daily-\(data.total)-\(entry.userId)-\(entry.rank)"
        guard signature != autoScrollSignature else { return }
        autoScrollSignature = signature
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(entry.userId, anchor: .center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContestLeaderboardView()
    }
}
