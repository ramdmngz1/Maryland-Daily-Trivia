//
//  LoadingView.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/3/26.
//  Updated: 2/10/26 - Trivia theme
//

import SwiftUI
import Combine

struct LoadingView: View {
    @State private var dotCount = 0
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                // Animated cowboy
                ZStack {
                    Circle()
                        .fill(ColorTheme.accent.opacity(0.15))
                        .frame(width: 120, height: 120)

                    ArmadilloSpriteView(size: 60)
                }

                VStack(spacing: 12) {
                    Text("Loading Maryland Trivia\(dots)")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))

                    Text("Rounding up today's questions")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTheme.textMuted)

                    ProgressView()
                        .tint(ColorTheme.accent)
                        .scaleEffect(1.2)
                        .padding(.top, 8)
                }
            }
        }
        .onReceive(timer) { _ in dotCount = (dotCount + 1) % 4 }
    }

    private var dots: String { String(repeating: ".", count: dotCount) }
}

// MARK: - Compact Loading
struct CompactLoadingView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(ColorTheme.accent)
                .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Loading questions...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? ColorTheme.textPrimary : Color(red: 0.165, green: 0.11, blue: 0.055))
                Text("This will only take a moment")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTheme.textMuted)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? ColorTheme.cardBg : .white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1)
        )
    }
}

// MARK: - Skeleton Loading
struct SkeletonLoadingView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTheme.accent.opacity(0.15))
                    .frame(height: 20)
                    .frame(maxWidth: 150)

                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTheme.accent.opacity(0.1))
                    .frame(height: 60)
            }
            .padding()

            VStack(spacing: 12) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTheme.accent.opacity(0.08))
                        .frame(height: 56)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

#Preview { LoadingView() }
#Preview("Compact") { CompactLoadingView().padding() }
#Preview("Skeleton") { SkeletonLoadingView() }
