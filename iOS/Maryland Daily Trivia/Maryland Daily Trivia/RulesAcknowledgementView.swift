//
//  RulesAcknowledgementView.swift
//  Maryland Daily Trivia
//

import SwiftUI

struct RulesAcknowledgementView: View {
    let username: String
    let onAcknowledge: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            NeonText(text: "WELCOME", size: 26)

                            Text(username.isEmpty ? "Player" : username)
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(primaryText)

                            Text("Please review the rules before your first round.")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)

                        AppCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("HOW IT WORKS")
                                    .font(.system(size: 13, weight: .bold, design: .serif))
                                    .tracking(2)
                                    .foregroundStyle(ColorTheme.accent)

                                ForEach(TriviaRules.items) { rule in
                                    ruleRow(rule)
                                }
                            }
                            .padding(20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 88)
                }

                VStack {
                    Spacer()
                    GlowingButton("OK, I Understand") {
                        HapticManager.buttonTap()
                        onAcknowledge()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarBackButtonHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    private func ruleRow(_ rule: TriviaRule) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rule.icon)
                .font(.system(size: 16))
                .foregroundStyle(ColorTheme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.title)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(primaryText)
                Text(rule.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryText: Color {
        colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? ColorTheme.textSecondary : Color(red: 0.353, green: 0.29, blue: 0.212)
    }
}

#Preview {
    RulesAcknowledgementView(username: "Ramon") {}
}
