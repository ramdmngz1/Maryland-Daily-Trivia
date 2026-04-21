//
//  ContestLeaderboardView.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/15/26.
//  Updated: 4/19/26 - Leaderboard styling aligned to Maryland screenshot tone
//

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
                    loadingView
                } else if let error = error {
                    errorView(error)
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

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.34))
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .redacted(reason: .placeholder)
            }
            ProgressView()
                .tint(ColorTheme.accent)
                .scaleEffect(1.0)
            Text("Loading rankings...")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Error

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

            if retryCooldownSeconds > 0 {
                Text("Retrying automatically in \(retryCooldownSeconds)s")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorTheme.warning)
                    .monospacedDigit()
            }

            GlowingButton("Retry", icon: "🔄") {
                Task { await loadLeaderboard(force: true) }
            }
            .padding(.horizontal, 60)
            .disabled(retryCooldownSeconds > 0)
            .opacity(retryCooldownSeconds > 0 ? 0.65 : 1.0)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Leaderboard Content

    private func leaderboardContent(_ data: LeaderboardResponse) -> some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 8) {
                Text("LEADERBOARD")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                    .shadow(color: .black.opacity(0.62), radius: 6, y: 3)

                Text("Today's Round • \(data.total) \(data.total == 1 ? "Player" : "Players")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))

                if isLoading {
                    ProgressView()
                        .tint(ColorTheme.accent)
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.48), Color.black.opacity(0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )

            if let entry = currentLeaderboardEntry {
                leaderboardRankPill(entry: entry)
            }

            // Top 3 Podium
            if data.entries.count >= 3 {
                podiumView(data.entries)
            }

            // Full list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(data.entries) { entry in
                            BarLeaderboardRow(
                                entry: entry,
                                isCurrentUser: entry.userId == getCurrentUserId()
                            )
                            .id(entry.userId)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    autoScrollToCurrentUser(in: data, proxy: proxy)
                }
                .onChange(of: data.entries.map(\.userId)) { _ in
                    autoScrollToCurrentUser(in: data, proxy: proxy)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.56), Color.black.opacity(0.44)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Daily Leaderboard Content

    private func dailyLeaderboardContent(_ data: DailyLeaderboardResponse) -> some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 8) {
                Text("LEADERBOARD")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                    .shadow(color: .black.opacity(0.62), radius: 6, y: 3)

                Text("Today's Total • \(data.total) \(data.total == 1 ? "Player" : "Players")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))

                if isLoading {
                    ProgressView()
                        .tint(ColorTheme.accent)
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.48), Color.black.opacity(0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )

            if let entry = currentDailyEntry {
                dailyRankPill(entry: entry)
            }

            // Top 3 Podium
            if data.entries.count >= 3 {
                dailyPodiumView(data.entries)
            }

            // Full list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(data.entries) { entry in
                            DailyLeaderboardRow(
                                entry: entry,
                                isCurrentUser: entry.userId == getCurrentUserId()
                            )
                            .id(entry.userId)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    autoScrollToCurrentDailyUser(in: data, proxy: proxy)
                }
                .onChange(of: data.entries.map(\.userId)) { _ in
                    autoScrollToCurrentDailyUser(in: data, proxy: proxy)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.56), Color.black.opacity(0.44)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private func dailyPodiumView(_ entries: [DailyLeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            dailyPodiumColumn(entry: entries[1], rank: 2, height: 100)
            dailyPodiumColumn(entry: entries[0], rank: 1, height: 120)
            dailyPodiumColumn(entry: entries[2], rank: 3, height: 85)
        }
    }

    private func dailyPodiumColumn(entry: DailyLeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "medal.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(rankMedalColor(rank))

            Text(truncateName(entry.username))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(entry.userId == getCurrentUserId() ? Color(red: 1.0, green: 0.86, blue: 0.24) : .white.opacity(0.95))
                .lineLimit(1)

            Text("\(entry.totalScore)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                .monospacedDigit()

            Text("\(entry.roundsPlayed) \(entry.roundsPlayed == 1 ? "round" : "rounds")")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            LinearGradient(
                colors: [Color(red: 0.27, green: 0.18, blue: 0.13), Color(red: 0.16, green: 0.11, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rank == 1 ? Color(red: 0.95, green: 0.74, blue: 0.18) : Color.white.opacity(0.17), lineWidth: rank == 1 ? 1.5 : 1)
        )
    }

    // MARK: - Podium

    private func podiumView(_ entries: [LeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 2nd place
            podiumColumn(entry: entries[1], rank: 2, height: 100)
            // 1st place
            podiumColumn(entry: entries[0], rank: 1, height: 120)
            // 3rd place
            podiumColumn(entry: entries[2], rank: 3, height: 85)
        }
    }

    private func podiumColumn(entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "medal.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(rankMedalColor(rank))

            Text(truncateName(entry.username))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(entry.userId == getCurrentUserId() ? Color(red: 1.0, green: 0.86, blue: 0.24) : .white.opacity(0.95))
                .lineLimit(1)

            Text("\(entry.score)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            LinearGradient(
                colors: [Color(red: 0.27, green: 0.18, blue: 0.13), Color(red: 0.16, green: 0.11, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rank == 1 ? Color(red: 0.95, green: 0.74, blue: 0.18) : Color.white.opacity(0.17), lineWidth: rank == 1 ? 1.5 : 1)
        )
    }

    private func rankMedalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return ColorTheme.textMuted
        }
    }

    // MARK: - Helpers

    private func loadLeaderboard(force: Bool = false) async {
        guard !isLoading else { return }
        if !force && retryCooldownSeconds > 0 {
            return
        }

        isLoading = true
        error = nil
        do {
            if let roundId = roundId {
                let data = try await manager.fetchLeaderboard(roundId: roundId)
                leaderboard = data
                let userId = getCurrentUserId()
                if let entry = data.entries.first(where: { $0.userId == userId }) {
                    userRank = entry.rank
                    currentLeaderboardEntry = entry
                }
            } else {
                let data = try await manager.fetchDailyLeaderboard()
                dailyLeaderboard = data
                let userId = getCurrentUserId()
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
        // In live round context (roundId set), poll quickly so scores appear
        // within a few seconds of being submitted. In standalone daily view,
        // 30 seconds is fine to stay well under the rate limit.
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

    private func getCurrentUserId() -> String {
        KeychainHelper.getOrCreateUserId()
    }

    private func truncateName(_ name: String) -> String {
        name.count > 12 ? String(name.prefix(10)) + "…" : name
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

    private func leaderboardRankPill(entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("Your Rank #\(entry.rank)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
            Spacer()
            Text("\(entry.score) pts")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.42))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private func dailyRankPill(entry: DailyLeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("Your Rank #\(entry.rank)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
            Spacer()
            Text("\(entry.totalScore) pts")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.42))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Bar Leaderboard Row

struct BarLeaderboardRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Group {
                if entry.rank <= 3 {
                    Image(systemName: rankSymbol)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(rankColor)
                } else {
                    Text("#\(entry.rank)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: 36)

            // Name
            HStack(spacing: 6) {
                Text(entry.username)
                    .font(.system(size: 16, weight: isCurrentUser ? .black : .bold, design: .rounded))
                    .foregroundStyle(isCurrentUser ? Color(red: 1.0, green: 0.86, blue: 0.24) : .white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isCurrentUser {
                    Text("(you)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score
            Text("\(entry.score)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                .lineLimit(1)
                .monospacedDigit()
                .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: isCurrentUser
                    ? [Color(red: 0.30, green: 0.22, blue: 0.09), Color(red: 0.20, green: 0.14, blue: 0.08)]
                    : [Color(red: 0.20, green: 0.14, blue: 0.11), Color(red: 0.13, green: 0.10, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCurrentUser ? Color(red: 0.95, green: 0.74, blue: 0.18) : Color.white.opacity(0.15), lineWidth: isCurrentUser ? 1.3 : 1)
        )
        .shadow(color: .black.opacity(isCurrentUser ? 0.28 : 0.18), radius: 7, y: 3)
    }

    private var rankSymbol: String {
        "medal.fill"
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // bronze
        default: return ColorTheme.textMuted
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ContestLeaderboardView()
    }
}
