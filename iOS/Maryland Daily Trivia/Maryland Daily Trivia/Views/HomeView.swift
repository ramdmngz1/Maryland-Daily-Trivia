//
//  HomeView.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//  Updated: 4/19/26 - Home screen style aligned to Maryland reference art
//

import SwiftUI

struct HomeView: View {
    @State private var showSettings = false
    @State private var showRulesAcknowledgement = false

    // Username entry
    @State private var showUsernameEntry = false
    @State private var username: String = KeychainHelper.getOrCreateUsername()
    @State private var requiresInitialRulesFlow = false

    var body: some View {
        NavigationStack {
            ZStack {
                MarylandHomeMenuBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topBar
                        logoSection
                        actionStack
                        resetStrip
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity)
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
    }

    // MARK: - Main Sections

    private var topBar: some View {
        HStack(spacing: 10) {
            Spacer()

            Button {
                HapticManager.buttonTap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.yellow)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var logoSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.18))
                    .frame(width: 230, height: 230)
                    .blur(radius: 24)

                Image("MarylandLogoCutout")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 315)
                    .shadow(color: .black.opacity(0.64), radius: 18, y: 10)
            }
        }
        .padding(.top, 2)
    }

    private var actionStack: some View {
        VStack(spacing: 12) {
            NavigationLink {
                LiveTriviaView()
            } label: {
                HomeMenuButton(title: "Start Game", icon: "play.fill", primary: true)
            }
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.buttonTap()
            })
            .accessibilityLabel("Start Game")

            NavigationLink {
                LeaderboardsView()
            } label: {
                HomeMenuButton(title: "Leaderboard", icon: "trophy.fill", primary: false)
            }
            .simultaneousGesture(TapGesture().onEnded {
                HapticManager.buttonTap()
            })
            .accessibilityLabel("Leaderboard")
        }
        .padding(.horizontal, 24)
    }

    private var resetStrip: some View {
        DailyResetCountdown()
    }

    private func acknowledgeRulesAndContinue() {
        UserDefaults.standard.set(true, forKey: TriviaRules.hasAcknowledgedKey)
        UserDefaults.standard.set(false, forKey: TriviaRules.pendingAcknowledgementKey)
        requiresInitialRulesFlow = false
        showRulesAcknowledgement = false
    }

    // MARK: - Helpers

    private var usernameDisplay: String {
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Anonymous" : cleaned
    }
}

private struct MarylandHomeMenuBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 14)
                    .scaleEffect(1.1)
                    .saturation(1.12)
                    .overlay(Color.black.opacity(0.4))

                LinearGradient(
                    colors: [.black.opacity(0.46), .clear, .black.opacity(0.56)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [.yellow.opacity(0.12), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
    }
}

private struct HomeMenuButton: View {
    let title: String
    let icon: String
    let primary: Bool

    var body: some View {
        let titleColor: Color = primary ? Color(red: 0.22, green: 0.10, blue: 0.04) : .white

        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(primary ? Color(red: 0.67, green: 0.06, blue: 0.05) : .yellow)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(primary ? 0.14 : 0.36), in: Circle())

            Text(title)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(titleColor)
        .background(
            buttonGradient,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(buttonStroke, lineWidth: 1.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(primary ? 0.26 : 0.12), lineWidth: 0.7)
                .padding(1.2)
        )
        .shadow(color: .black.opacity(primary ? 0.45 : 0.35), radius: 8, y: 4)
    }

    private var buttonGradient: LinearGradient {
        if primary {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.95, blue: 0.35), Color(red: 1.0, green: 0.82, blue: 0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color(red: 0.22, green: 0.14, blue: 0.12), Color(red: 0.13, green: 0.09, blue: 0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var buttonStroke: Color {
        primary ? Color(red: 0.88, green: 0.65, blue: 0.16) : Color.white.opacity(0.20)
    }
}

private struct DailyResetCountdown: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Self.timeUntilMidnightET(from: context.date)
            Text("Daily Challenge resets in: \(remaining)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .accessibilityLabel("Daily Challenge resets in \(remaining)")
        }
    }

    private static func timeUntilMidnightET(from date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        guard let midnight = calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            return "00:00:00"
        }
        let seconds = Int(max(0, midnight.timeIntervalSince(date)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
