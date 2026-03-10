//
//  UsernameEntryView.swift
//  Maryland Daily Trivia
//
//  Updated: 2/10/26 - Trivia theme redesign
//

import SwiftUI
import Foundation

enum UsernameEntryMode {
    case onboarding
    case editing
}

struct UsernameEntryView: View {
    @Binding var username: String
    @Binding var isPresented: Bool
    let mode: UsernameEntryMode
    var onSaved: (() -> Void)? = nil
    @State private var inputName: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 24) {
                    Spacer()

                    // Logo
                    VStack(spacing: 8) {
                        ArmadilloSpriteView(size: 64)

                        NeonText(text: "TEXAS DAILY", size: 24)

                        Text("TRIVIA")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    // Welcome text
                    VStack(spacing: 8) {
                        Text(titleText)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

                        Text(subtitleText)
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Input field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR NAME")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(ColorTheme.textMuted)
                            .padding(.leading, 4)

                        TextField("", text: $inputName, prompt: Text(fieldPromptText).foregroundColor(ColorTheme.textMuted.opacity(0.6)))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                            .padding(16)
                            .background(colorScheme == .dark ? ColorTheme.cardBg : Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFocused ? ColorTheme.accent : (colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder), lineWidth: isFocused ? 2 : 1)
                            )
                            .focused($isFocused)
                            .autocorrectionDisabled()
                            .onChange(of: inputName) { newValue in
                                if newValue.count > 20 {
                                    inputName = String(newValue.prefix(20))
                                }
                            }

                        Text("\(inputName.count)/20")
                            .font(.system(size: 11))
                            .foregroundStyle(inputName.count >= 20 ? ColorTheme.warning : ColorTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 32)

                    // Start button
                    Button {
                        saveUsername()
                    } label: {
                        HStack {
                            Text(actionButtonTitle)
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(
                            sanitized(inputName).trimmingCharacters(in: .whitespaces).isEmpty
                                ? LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [ColorTheme.accent, ColorTheme.neon], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: sanitized(inputName).trimmingCharacters(in: .whitespaces).isEmpty ? .clear : (colorScheme == .dark ? ColorTheme.neon.opacity(0.3) : ColorTheme.accent.opacity(0.25)), radius: 12, x: 0, y: 4)
                    }
                    .disabled(sanitized(inputName).trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .topTrailing) {
                if mode == .editing {
                    Button {
                        HapticManager.buttonTap()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ColorTheme.accent)
                            .frame(width: 36, height: 36)
                            .background((colorScheme == .dark ? ColorTheme.cardBg : Color.white).opacity(0.9))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1))
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 20)
                }
            }
            .onAppear {
                if inputName.isEmpty {
                    inputName = username
                }
                isFocused = true
            }
        }
    }

    private var titleText: String {
        switch mode {
        case .onboarding: return "Welcome, partner!"
        case .editing: return "Edit Your Name"
        }
    }

    private var subtitleText: String {
        switch mode {
        case .onboarding:
            return "Enter your name to compete on the live leaderboard"
        case .editing:
            return "Update the name shown for you on the leaderboard"
        }
    }

    private var actionButtonTitle: String {
        switch mode {
        case .onboarding: return "START PLAYING"
        case .editing: return "SAVE NAME"
        }
    }

    private var fieldPromptText: String {
        switch mode {
        case .onboarding: return "Enter your name"
        case .editing: return "Update your name"
        }
    }

    private func sanitized(_ raw: String) -> String {
        // Allow letters, numbers, spaces, and -_.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_."))
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredScalars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character(" ") }
        var result = String(filteredScalars).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Collapse multiple spaces and cap length to 20 chars
        if result.count > 20 {
            result = String(result.prefix(20))
        }
        // Prevent empty or whitespace-only names
        let fallback = "Anonymous"
        let final = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return final.isEmpty ? fallback : final
    }

    private func saveUsername() {
        let cleaned = sanitized(inputName)
        guard !cleaned.isEmpty, cleaned != "Anonymous" || !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        username = cleaned
        KeychainHelper.saveUsername(cleaned)
        onSaved?()
        HapticManager.notification(type: .success)
        isPresented = false
    }
}

#Preview {
    UsernameEntryView(username: .constant(""), isPresented: .constant(true), mode: .onboarding)
}
