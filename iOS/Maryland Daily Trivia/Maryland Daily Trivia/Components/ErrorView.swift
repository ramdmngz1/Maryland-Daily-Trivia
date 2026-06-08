//
//  ErrorView.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/3/26.
//  Updated: 2/10/26 - Trivia theme
//

import SwiftUI

// MARK: - Error Types
enum TriviaError {
    case loadingFailed
    case networkError
    case questionsEmpty
    case gameCenterError
    case adLoadError
    case unknown(String)

    var title: String {
        switch self {
        case .loadingFailed: return "Loading Failed"
        case .networkError: return "Network Error"
        case .questionsEmpty: return "No Questions Available"
        case .gameCenterError: return "Game Center Error"
        case .adLoadError: return "Ad Loading Issue"
        case .unknown: return "Something Went Wrong"
        }
    }

    var message: String {
        switch self {
        case .loadingFailed: return "We couldn't load today's trivia questions. Please check your connection and try again."
        case .networkError: return "Unable to connect to the internet. Please check your connection and try again."
        case .questionsEmpty: return "We couldn't find any questions in the trivia bank. This shouldn't happen!"
        case .gameCenterError: return "There was a problem connecting to Game Center. Make sure you're signed in."
        case .adLoadError: return "Ads couldn't be loaded. You can continue playing without interruption."
        case .unknown(let details): return details.isEmpty ? "An unexpected error occurred. Please try again." : details
        }
    }

    var icon: String {
        switch self {
        case .loadingFailed: return "exclamationmark.triangle.fill"
        case .networkError: return "wifi.slash"
        case .questionsEmpty: return "questionmark.folder.fill"
        case .gameCenterError: return "gamecontroller.fill"
        case .adLoadError: return "rectangle.stack.fill.badge.minus"
        case .unknown: return "exclamationmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .loadingFailed, .networkError, .unknown: return ColorTheme.error
        case .questionsEmpty: return ColorTheme.warning
        case .gameCenterError: return ColorTheme.accent
        case .adLoadError: return ColorTheme.accent
        }
    }
}

// MARK: - Main Error View
struct ErrorView: View {
    let error: TriviaError
    let retry: () -> Void
    let dismiss: (() -> Void)?
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme

    init(error: TriviaError, retry: @escaping () -> Void, dismiss: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
        self.dismiss = dismiss
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(error.iconColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)

                    Image(systemName: error.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(error.iconColor)
                }
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

                VStack(spacing: 12) {
                    Text(error.title)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                        .multilineTextAlignment(.center)

                    Text(error.message)
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    GlowingButton("Try Again", icon: "🔄") {
                        HapticManager.impact(style: .medium)
                        retry()
                    }

                    if let dismiss = dismiss {
                        Button {
                            HapticManager.impact(style: .light)
                            dismiss()
                        } label: {
                            Text("Go Back")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(ColorTheme.accent)
                                .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            isAnimating = true
            HapticManager.notification(type: .error)
        }
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String
    let retry: (() -> Void)?
    @Binding var isShowing: Bool
    @State private var offset: CGFloat = -100
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTheme.warning)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                .lineLimit(2)

            Spacer()

            if let retry = retry {
                Button("Retry") {
                    HapticManager.impact(style: .light)
                    retry()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTheme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1))
        .padding(.horizontal)
        .offset(y: offset)
        .onChange(of: isShowing) { newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offset = newValue ? 0 : -100
            }
        }
        .onAppear { offset = isShowing ? 0 : -100 }
    }
}

#Preview { ErrorView(error: .loadingFailed, retry: {}, dismiss: {}) }
#Preview("Network") { ErrorView(error: .networkError, retry: {}, dismiss: {}) }
