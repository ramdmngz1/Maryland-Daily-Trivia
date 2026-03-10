//
//  ContestLeaderboardView.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 1/15/26.
//  Updated: 2/10/26 - Trivia theme redesign
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
            AppBackground()

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
                    .fill((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.7))
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder).opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .redacted(reason: .placeholder)
            }
            ProgressView()
                .tint(ColorTheme.accent)
                .scaleEffect(1.0)
            Text("Loading rankings...")
                .font(.system(size: 14))
                .foregroundStyle(ColorTheme.textMuted)
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
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(ColorTheme.textMuted)
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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                NeonText(text: "LEADERBOARD", size: 20)
                Text("Today's Round • \(data.total) Players")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTheme.textMuted)

                if isLoading {
                    ProgressView()
                        .tint(ColorTheme.accent)
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 16)

            if let entry = currentLeaderboardEntry {
                leaderboardRankPill(entry: entry)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Top 3 Podium
            if data.entries.count >= 3 {
                podiumView(data.entries)
            }

            // Full list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(data.entries) { entry in
                            BarLeaderboardRow(
                                entry: entry,
                                isCurrentUser: entry.userId == getCurrentUserId()
                            )
                            .id(entry.userId)
                        }
                    }
                }
                .onAppear {
                    autoScrollToCurrentUser(in: data, proxy: proxy)
                }
                .onChange(of: data.entries.map(\.userId)) { _ in
                    autoScrollToCurrentUser(in: data, proxy: proxy)
                }
            }
            .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Daily Leaderboard Content

    private func dailyLeaderboardContent(_ data: DailyLeaderboardResponse) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                NeonText(text: "LEADERBOARD", size: 20)
                Text("Today's Total • \(data.total) Players")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTheme.textMuted)

                if isLoading {
                    ProgressView()
                        .tint(ColorTheme.accent)
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 16)

            if let entry = currentDailyEntry {
                dailyRankPill(entry: entry)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Top 3 Podium
            if data.entries.count >= 3 {
                dailyPodiumView(data.entries)
            }

            // Full list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(data.entries) { entry in
                            DailyLeaderboardRow(
                                entry: entry,
                                isCurrentUser: entry.userId == getCurrentUserId()
                            )
                            .id(entry.userId)
                        }
                    }
                }
                .onAppear {
                    autoScrollToCurrentDailyUser(in: data, proxy: proxy)
                }
                .onChange(of: data.entries.map(\.userId)) { _ in
                    autoScrollToCurrentDailyUser(in: data, proxy: proxy)
                }
            }
            .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func dailyPodiumView(_ entries: [DailyLeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            dailyPodiumColumn(entry: entries[1], medal: "🥈", height: 100)
            dailyPodiumColumn(entry: entries[0], medal: "🥇", height: 120)
            dailyPodiumColumn(entry: entries[2], medal: "🥉", height: 85)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func dailyPodiumColumn(entry: DailyLeaderboardEntry, medal: String, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(medal)
                .font(.system(size: 28))

            Text(truncateName(entry.username))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(entry.userId == getCurrentUserId() ? ColorTheme.accent : (colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)))
                .lineLimit(1)

            Text("\(entry.totalScore)")
                .font(.system(size: 14, weight: .black, design: .serif))
                .foregroundStyle(ColorTheme.accent)

            Text("\(entry.roundsPlayed) rounds")
                .font(.system(size: 9))
                .foregroundStyle(ColorTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? ColorTheme.cardBg : .white)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1)
                WoodTextureOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        )
    }

    // MARK: - Podium

    private func podiumView(_ entries: [LeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 2nd place
            podiumColumn(entry: entries[1], medal: "🥈", height: 100)
            // 1st place
            podiumColumn(entry: entries[0], medal: "🥇", height: 120)
            // 3rd place
            podiumColumn(entry: entries[2], medal: "🥉", height: 85)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func podiumColumn(entry: LeaderboardEntry, medal: String, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(medal)
                .font(.system(size: 28))

            Text(truncateName(entry.username))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(entry.userId == getCurrentUserId() ? ColorTheme.accent : (colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)))
                .lineLimit(1)

            Text("\(entry.score)")
                .font(.system(size: 14, weight: .black, design: .serif))
                .foregroundStyle(ColorTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? ColorTheme.cardBg : .white)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1)
                WoodTextureOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        )
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak refreshTimer] _ in
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
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(ColorTheme.accent)
            Spacer()
            Text("\(entry.score) pts")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(ColorTheme.accent.opacity(0.35), lineWidth: 1))
    }

    private func dailyRankPill(entry: DailyLeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("Your Rank #\(entry.rank)")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(ColorTheme.accent)
            Spacer()
            Text("\(entry.totalScore) pts")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(ColorTheme.accent.opacity(0.35), lineWidth: 1))
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
                    Text(rankEmoji)
                        .font(.system(size: 18))
                } else {
                    Text("#\(entry.rank)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
            .frame(width: 36)

            // Name
            HStack(spacing: 6) {
                Text(entry.username)
                    .font(.system(size: 15, weight: isCurrentUser ? .bold : .regular))
                    .foregroundStyle(isCurrentUser ? ColorTheme.accent : (colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isCurrentUser {
                    Text("(you)")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score
            Text("\(entry.score)")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                .lineLimit(1)
                .monospacedDigit()
                .frame(minWidth: 76, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrentUser ? ColorTheme.accent.opacity(0.14) : .clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle((colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder).opacity(0.3)),
            alignment: .bottom
        )
        .overlay(
            isCurrentUser ?
                Rectangle()
                    .frame(width: 3)
                    .foregroundStyle(ColorTheme.accent)
                : nil,
            alignment: .leading
        )
        .shadow(color: isCurrentUser ? ColorTheme.neon.opacity(0.12) : .clear, radius: 6, y: 1)
    }

    private var rankEmoji: String {
        switch entry.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ContestLeaderboardView()
    }
}
