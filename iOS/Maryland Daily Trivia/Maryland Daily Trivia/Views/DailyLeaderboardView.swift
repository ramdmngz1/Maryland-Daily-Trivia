import SwiftUI

struct DailyLeaderboardView: View {
    @StateObject private var manager = ContestManager.shared
    @State private var leaderboard: DailyLeaderboardResponse?
    @State private var currentUserEntry: DailyLeaderboardEntry?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var refreshTimer: Timer?
    @State private var autoScrollSignature = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            MarylandLeaderboardBackground()

            VStack(spacing: 0) {
                if isLoading && leaderboard == nil {
                    AppLoadingStateView(
                        title: "Loading rankings",
                        message: "Fetching today's Maryland trivia scores."
                    )
                } else if let error = error, leaderboard == nil {
                    AppErrorStateView(
                        title: "Failed to load leaderboard",
                        message: error.localizedDescription,
                        action: AppStateAction("Retry", systemImage: "arrow.clockwise") {
                            Task { await loadLeaderboard() }
                        }
                    )
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
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ColorTheme.accent)
                .scaleEffect(1.5)
            Text("Loading rankings...")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(ColorTheme.error.opacity(0.7))

            Text("Failed to load leaderboard")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            GlowingButton("Retry", icon: "\u{1F504}") {
                Task { await loadLeaderboard() }
            }
            .padding(.horizontal, 60)
        }
        .frame(maxHeight: .infinity)
    }

    private func leaderboardContent(_ data: DailyLeaderboardResponse) -> some View {
        VStack(spacing: 12) {
            LeaderboardHeader(
                title: "LEADERBOARD",
                subtitle: "Today's Scores \u{2022} \(data.total) Players",
                isLoading: isLoading
            )

            if let entry = currentUserEntry {
                LeaderboardRankPill(rank: entry.rank, scoreText: "\(entry.totalScore) pts")
            }

            if data.entries.count >= 3 {
                HStack(alignment: .bottom, spacing: 8) {
                    LeaderboardPodiumColumn(
                        name: data.entries[1].username,
                        isCurrentUser: data.entries[1].userId == leaderboardCurrentUserId(),
                        rank: 2, height: 100,
                        scoreText: "\(data.entries[1].totalScore)",
                        subtitle: "\(data.entries[1].roundsPlayed) rnd\(data.entries[1].roundsPlayed == 1 ? "" : "s")"
                    )
                    LeaderboardPodiumColumn(
                        name: data.entries[0].username,
                        isCurrentUser: data.entries[0].userId == leaderboardCurrentUserId(),
                        rank: 1, height: 120,
                        scoreText: "\(data.entries[0].totalScore)",
                        subtitle: "\(data.entries[0].roundsPlayed) rnd\(data.entries[0].roundsPlayed == 1 ? "" : "s")"
                    )
                    LeaderboardPodiumColumn(
                        name: data.entries[2].username,
                        isCurrentUser: data.entries[2].userId == leaderboardCurrentUserId(),
                        rank: 3, height: 85,
                        scoreText: "\(data.entries[2].totalScore)",
                        subtitle: "\(data.entries[2].roundsPlayed) rnd\(data.entries[2].roundsPlayed == 1 ? "" : "s")"
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

    private func loadLeaderboard() async {
        isLoading = true
        error = nil
        do {
            let data = try await manager.fetchDailyLeaderboard()
            leaderboard = data
            let userId = leaderboardCurrentUserId()
            currentUserEntry = data.entries.first(where: { $0.userId == userId })
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak refreshTimer] _ in
            guard refreshTimer?.isValid == true else { return }
            Task { await loadLeaderboard() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func autoScrollToCurrentUser(in data: DailyLeaderboardResponse, proxy: ScrollViewProxy) {
        guard let entry = currentUserEntry else { return }
        let signature = "\(data.total)-\(data.entries.first?.userId ?? "")-\(entry.userId)-\(entry.rank)"
        guard signature != autoScrollSignature else { return }
        autoScrollSignature = signature

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(entry.userId, anchor: .center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DailyLeaderboardView()
            .navigationTitle("Leaderboard")
    }
}
