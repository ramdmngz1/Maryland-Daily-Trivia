//
//  DailyLeaderboardView.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 2/13/26.
//

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
            AppBackground()

            VStack(spacing: 0) {
                if isLoading && leaderboard == nil {
                    loadingView
                } else if let error = error, leaderboard == nil {
                    errorView(error)
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
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ColorTheme.accent)
                .scaleEffect(1.5)
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

            GlowingButton("Retry", icon: "🔄") {
                Task { await loadLeaderboard() }
            }
            .padding(.horizontal, 60)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Leaderboard Content

    private func leaderboardContent(_ data: DailyLeaderboardResponse) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                NeonText(text: "LEADERBOARD", size: 20)
                Text("Today's Rounds • \(data.total) Players")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTheme.textMuted)

                if isLoading {
                    ProgressView()
                        .tint(ColorTheme.accent)
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 16)

            if let entry = currentUserEntry {
                userRankPill(entry: entry)
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
                            DailyLeaderboardRow(
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

    // MARK: - Podium

    private func podiumView(_ entries: [DailyLeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            podiumColumn(entry: entries[1], medal: "🥈", height: 100)
            podiumColumn(entry: entries[0], medal: "🥇", height: 120)
            podiumColumn(entry: entries[2], medal: "🥉", height: 85)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func podiumColumn(entry: DailyLeaderboardEntry, medal: String, height: CGFloat) -> some View {
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

            Text("\(entry.roundsPlayed) rnd\(entry.roundsPlayed == 1 ? "" : "s")")
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

    // MARK: - Helpers

    private func loadLeaderboard() async {
        isLoading = true
        error = nil
        do {
            let data = try await manager.fetchDailyLeaderboard()
            leaderboard = data
            let userId = getCurrentUserId()
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

    private func getCurrentUserId() -> String {
        KeychainHelper.getOrCreateUserId()
    }

    private func truncateName(_ name: String) -> String {
        name.count > 12 ? String(name.prefix(10)) + "…" : name
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

    private func userRankPill(entry: DailyLeaderboardEntry) -> some View {
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
        .overlay(
            Capsule()
                .stroke(ColorTheme.accent.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Daily Leaderboard Row

struct DailyLeaderboardRow: View {
    let entry: DailyLeaderboardEntry
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
            VStack(alignment: .leading, spacing: 2) {
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

                Text("\(entry.roundsPlayed) round\(entry.roundsPlayed == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Total Score
            Text("\(entry.totalScore)")
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

#Preview {
    NavigationStack {
        DailyLeaderboardView()
            .navigationTitle("Leaderboard")
    }
}
