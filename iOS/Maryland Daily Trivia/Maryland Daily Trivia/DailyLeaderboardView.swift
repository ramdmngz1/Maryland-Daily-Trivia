//
//  DailyLeaderboardView.swift
//  Maryland Daily Trivia
//
//  Created by Claude on 2/13/26.
//  Updated: 4/19/26 - Leaderboard styling aligned to Maryland screenshot tone
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
            MarylandLeaderboardBackground()

            VStack(spacing: 0) {
                if isLoading && leaderboard == nil {
                    loadingView
                } else if let error = error, leaderboard == nil {
                    errorView(error)
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

    // MARK: - Loading

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

            GlowingButton("Retry", icon: "🔄") {
                Task { await loadLeaderboard() }
            }
            .padding(.horizontal, 60)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Leaderboard Content

    private func leaderboardContent(_ data: DailyLeaderboardResponse) -> some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 8) {
                Text("LEADERBOARD")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.24))
                    .shadow(color: .black.opacity(0.62), radius: 6, y: 3)

                Text("Today's Scores • \(data.total) Players")
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

            if let entry = currentUserEntry {
                userRankPill(entry: entry)
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

    // MARK: - Podium

    private func podiumView(_ entries: [DailyLeaderboardEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            podiumColumn(entry: entries[1], rank: 2, height: 100)
            podiumColumn(entry: entries[0], rank: 1, height: 120)
            podiumColumn(entry: entries[2], rank: 3, height: 85)
        }
    }

    private func podiumColumn(entry: DailyLeaderboardEntry, rank: Int, height: CGFloat) -> some View {
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

            Text("\(entry.roundsPlayed) rnd\(entry.roundsPlayed == 1 ? "" : "s")")
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

    private func rankMedalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return ColorTheme.textMuted
        }
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
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
            VStack(alignment: .leading, spacing: 2) {
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

                Text("\(entry.roundsPlayed) round\(entry.roundsPlayed == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Total Score
            Text("\(entry.totalScore)")
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
        switch entry.rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
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

#Preview {
    NavigationStack {
        DailyLeaderboardView()
            .navigationTitle("Leaderboard")
    }
}
