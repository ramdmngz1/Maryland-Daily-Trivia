//
//  HomeView.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//  Updated: 2/10/26 - Trivia theme redesign
//

import SwiftUI

struct HomeView: View {
    @State private var showSettings = false
    @State private var showRulesAcknowledgement = false
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotionEnabled = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    // Username entry
    @State private var showUsernameEntry = false
    @State private var username: String = KeychainHelper.getOrCreateUsername()
    @State private var requiresInitialRulesFlow = false

    // Live player count
    @State private var activePlayerCount: Int = 0
    @State private var playerCountTimer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                HomeAmbientMotionLayer(isEnabled: !effectiveReduceMotion)

                ScrollView {
                    VStack(spacing: 20) {
                        topBar
                        logoSection
                        usernameBadge
                        liveContestCard
                        Spacer(minLength: 24)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings, onDismiss: {
            username = KeychainHelper.getOrCreateUsername()
        }) {
            SettingsView()
        }
        .sheet(isPresented: $showUsernameEntry) {
            UsernameEntryView(username: $username, isPresented: $showUsernameEntry, mode: .onboarding) {
                if requiresInitialRulesFlow {
                    UserDefaults.standard.set(true, forKey: TriviaRules.pendingAcknowledgementKey)
                    showRulesAcknowledgement = true
                }
            }
        }
        .sheet(isPresented: $showRulesAcknowledgement) {
            RulesAcknowledgementView(username: usernameDisplay) {
                acknowledgeRulesAndContinue()
            }
            .interactiveDismissDisabled(true)
        }
        .onAppear {
            username = KeychainHelper.getOrCreateUsername()
            if username.isEmpty {
                requiresInitialRulesFlow = true
                showUsernameEntry = true
                return
            }

            requiresInitialRulesFlow = false

            if UserDefaults.standard.bool(forKey: TriviaRules.pendingAcknowledgementKey) {
                showRulesAcknowledgement = true
                return
            }

            if UserDefaults.standard.object(forKey: TriviaRules.hasAcknowledgedKey) == nil {
                // Existing users keep their current flow and are treated as already acknowledged.
                UserDefaults.standard.set(true, forKey: TriviaRules.hasAcknowledgedKey)
            }
        }
        .task {
            await fetchPlayerCount()
            playerCountTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
                Task { await fetchPlayerCount() }
            }
        }
        .onDisappear {
            playerCountTimer?.invalidate()
            playerCountTimer = nil
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                HapticManager.buttonTap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(cardColor.opacity(0.8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(borderColor, lineWidth: 1))
            }

            Spacer()

            NavigationLink {
                LeaderboardsView()
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(cardColor.opacity(0.8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(borderColor, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 6) {
            ZStack {
                // Twinkling stars
                HStack {
                    TwinklingStar(delay: 0)
                    Spacer()
                    TwinklingStar(delay: 0.5)
                    Spacer()
                    TwinklingStar(delay: 1.0)
                    Spacer()
                    TwinklingStar(delay: 1.5)
                }
                .padding(.horizontal, 30)

                VStack(spacing: 0) {
                    ArmadilloSpriteView(size: 160)
                        .padding(.bottom, -14)

                    NeonText(text: "MARYLAND DAILY", size: 36)

                    Text("TRIVIA")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
        }
        .padding(.vertical, 0)
    }

    private var usernameBadge: some View {
        Text(usernameDisplay)
            .font(.system(size: 13, weight: .semibold, design: .serif))
            .foregroundStyle(primaryText)
            .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(cardColor.opacity(0.8))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }

    // MARK: - Live Contest Card

    private var liveContestCard: some View {
        AppCard {
            VStack(spacing: 16) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            LiveDot()
                            Text("LIVE NOW")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ColorTheme.success)
                                .tracking(1)
                        }
                        Text("Today's Round")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(primaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Players")
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTheme.textMuted)
                        Text("\(activePlayerCount)")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(ColorTheme.accent)
                    }
                }

                // Category pills
                HStack(spacing: 6) {
                    ForEach(["History", "Geography", "Culture", "Sports", "Food"], id: \.self) { cat in
                        CategoryPill(name: cat)
                    }
                }

                // Start button
                NavigationLink {
                    LiveTriviaView()
                } label: {
                    HStack {
                        Text("START QUIZ")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [ColorTheme.accent, ColorTheme.neon],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.3) : ColorTheme.accent.opacity(0.25), radius: 12, x: 0, y: 4)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.buttonTap()
                })
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Data Fetching

    private func fetchPlayerCount() async {
        guard let url = URL(string: "https://maryland-trivia-contest.f22682jcz6.workers.dev/api/live-state") else { return }
        do {
            let (data, _) = try await SecureSession.shared.data(from: url)
            let state = try JSONDecoder().decode(LiveTriviaState.self, from: data)
            activePlayerCount = state.activePlayerCount
        } catch {
            #if DEBUG
            print("Failed to fetch player count:", error.localizedDescription)
            #endif
        }
    }

    private func acknowledgeRulesAndContinue() {
        UserDefaults.standard.set(true, forKey: TriviaRules.hasAcknowledgedKey)
        UserDefaults.standard.set(false, forKey: TriviaRules.pendingAcknowledgementKey)
        requiresInitialRulesFlow = false
        showRulesAcknowledgement = false
    }

    // MARK: - Helpers

    private var cardColor: Color {
        colorScheme == .dark ? ColorTheme.cardBg : .white
    }

    private var borderColor: Color {
        colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder
    }

    private var primaryText: Color {
        colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)
    }

    private var usernameDisplay: String {
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Anonymous" : cleaned
    }

    private var effectiveReduceMotion: Bool {
        reduceMotionEnabled || systemReduceMotion
    }

}

private struct HomeAmbientMotionLayer: View {
    let isEnabled: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { geometry in
            if isEnabled {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ColorTheme.neon.opacity(0.12),
                                    ColorTheme.neon.opacity(0.015),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 170
                            )
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 42)
                        .offset(
                            x: drift ? geometry.size.width * 0.16 : -geometry.size.width * 0.14,
                            y: drift ? -125 : 45
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ColorTheme.accent.opacity(0.09),
                                    ColorTheme.accent.opacity(0.015),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 150
                            )
                        )
                        .frame(width: 260, height: 260)
                        .blur(radius: 34)
                        .offset(
                            x: drift ? -geometry.size.width * 0.12 : geometry.size.width * 0.16,
                            y: drift ? geometry.size.height * 0.1 : geometry.size.height * 0.03
                        )
                }
                .opacity(0.3)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeInOut(duration: 14.0).repeatForever(autoreverses: true)) {
                        drift.toggle()
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
