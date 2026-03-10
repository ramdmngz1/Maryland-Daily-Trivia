//
//  SettingsView.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/5/26.
//  Updated: 2/10/26 - Trivia theme redesign
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @AppStorage(AppPreferences.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceMotionEnabled = false

    @State private var showUsernameEntry = false
    @State private var showHowItWorks = false
    @State private var username: String = {
        let name = KeychainHelper.getOrCreateUsername()
        return name.isEmpty ? "Anonymous" : name
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        sectionHeader("Profile")
                        settingsCard(interactive: true) {
                            valueRow(
                                icon: "person.fill",
                                title: "Username",
                                value: username,
                                valueFont: .system(size: 15, weight: .semibold, design: .serif)
                            )
                            rowDivider
                            actionRow(icon: "pencil", title: "Change Username") {
                                HapticManager.buttonTap()
                                showUsernameEntry = true
                            }
                        }

                        sectionHeader("Experience")
                        settingsCard(interactive: true) {
                            toggleRow(icon: "iphone.radiowaves.left.and.right", title: "Haptics", isOn: $hapticsEnabled)
                            rowDivider
                            toggleRow(icon: "figure.walk", title: "Reduce Motion", isOn: $reduceMotionEnabled)
                        }
                        Text("Reduce Motion applies in addition to iOS accessibility settings.")
                            .font(.system(size: 12))
                            .foregroundStyle(textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)

                        sectionHeader("About")
                        settingsCard(interactive: true) {
                            valueRow(
                                icon: "info.circle",
                                title: "Version",
                                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            )
                            rowDivider
                            linkRow(
                                icon: "hand.raised.fill",
                                title: "Privacy Policy",
                                urlString: "https://www.copanostudios.com/privacy-maryland-daily-trivia"
                            )
                            rowDivider
                            linkRow(
                                icon: "questionmark.circle",
                                title: "Support",
                                urlString: "https://www.copanostudios.com/support-maryland-daily-trivia"
                            )
                            rowDivider
                            Text("© 2026 Copano Studios. Not affiliated with the State of Maryland.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 12)
                        }

                        sectionHeader("How It Works")
                        settingsCard {
                            VStack(spacing: 0) {
                                ForEach(Array(TriviaRules.items.enumerated()), id: \.element.id) { index, rule in
                                    howItWorksRow(rule: rule, index: index)
                                        .opacity(showHowItWorks ? 1 : 0)
                                        .offset(y: showHowItWorks ? 0 : 8)
                                        .animation(
                                            shouldReduceMotion ? nil : .easeOut(duration: 0.35).delay(Double(index) * 0.06),
                                            value: showHowItWorks
                                        )
                                    if index < TriviaRules.items.count - 1 {
                                        rowDivider
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ColorTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.buttonTap()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [ColorTheme.accent.opacity(0.92), ColorTheme.neon.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(ColorTheme.accent.opacity(0.42), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .buttonStyle(PressScaleButtonStyle(reduceMotion: shouldReduceMotion))
                }
            }
            .sheet(isPresented: $showUsernameEntry) {
                UsernameEntryView(username: $username, isPresented: $showUsernameEntry, mode: .editing)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            showHowItWorks = false
            if shouldReduceMotion {
                showHowItWorks = true
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    showHowItWorks = true
                }
            }
        }
        .onChange(of: hapticsEnabled) { _ in
            HapticManager.selection()
        }
        .onChange(of: reduceMotionEnabled) { _ in
            HapticManager.selection()
        }
    }

    private var shouldReduceMotion: Bool {
        reduceMotionEnabled || accessibilityReduceMotion
    }

    private var textPrimary: Color {
        colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)
    }

    private var textSecondary: Color {
        colorScheme == .dark ? ColorTheme.textSecondary : Color(red: 0.353, green: 0.29, blue: 0.212)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(ColorTheme.cardBorder.opacity(0.75))
            .frame(height: 1)
            .padding(.leading, 56)
            .padding(.trailing, 12)
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black))
            .tracking(3)
            .foregroundStyle(ColorTheme.accent)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 2)
    }

    @ViewBuilder
    private func settingsCard(interactive: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTheme.cardBgHover.opacity(0.94),
                            ColorTheme.cardBg.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(ColorTheme.accent.opacity(0.26), lineWidth: 1)
                )
                .shadow(
                    color: interactive ? ColorTheme.neon.opacity(0.12) : .clear,
                    radius: interactive ? 14 : 0,
                    y: interactive ? 5 : 0
                )
        )
    }

    @ViewBuilder
    private func valueRow(
        icon: String,
        title: String,
        value: String,
        valueFont: Font = .system(size: 15, weight: .medium)
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTheme.accent)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(textPrimary)

            Spacer()

            Text(value)
                .font(valueFont)
                .foregroundStyle(ColorTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTheme.accent)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: shouldReduceMotion))
    }

    @ViewBuilder
    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(textPrimary)
            }
        }
        .tint(ColorTheme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .animation(
            shouldReduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82),
            value: isOn.wrappedValue
        )
    }

    @ViewBuilder
    private func linkRow(icon: String, title: String, urlString: String) -> some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            HapticManager.buttonTap()
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: shouldReduceMotion))
    }

    @ViewBuilder
    private func howItWorksRow(rule: TriviaRule, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(ColorTheme.accent.opacity(0.16))
                        .overlay(
                            Capsule()
                                .stroke(ColorTheme.accent.opacity(0.45), lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(rule.title)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(textPrimary)
                Text(rule.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}

#Preview {
    SettingsView()
}
