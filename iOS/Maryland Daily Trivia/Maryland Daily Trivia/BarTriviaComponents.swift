//
//  BarTriviaComponents.swift
//  Maryland Daily Trivia
//
//  Created: 2/10/26 - Shared UI components for trivia theme
//

import SwiftUI

// MARK: - Wood Texture Overlay
struct WoodTextureOverlay: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Canvas { context, size in
            // Vertical grain lines
            for x in stride(from: 0, to: size.width, by: 42) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color(red: 0.55, green: 0.38, blue: 0.10).opacity(colorScheme == .dark ? 0.06 : 0.03)), lineWidth: 1)
            }
            // Horizontal grain lines
            for y in stride(from: 0, to: size.height, by: 9) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color(red: 0.55, green: 0.38, blue: 0.10).opacity(colorScheme == .dark ? 0.03 : 0.015)), lineWidth: 1)
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - App Card (card with wood texture)
struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? ColorTheme.cardBg : .white)
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? ColorTheme.cardBorder : ColorTheme.lightBorder, lineWidth: 1)
            WoodTextureOverlay()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            content
        }
    }
}

// MARK: - Neon Text
struct NeonText: View {
    let text: String
    var size: CGFloat = 24
    var color: Color = ColorTheme.accent
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .serif))
            .foregroundStyle(color)
            .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.3) : .clear, radius: 7, x: 0, y: 0)
            .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.15) : .clear, radius: 20, x: 0, y: 0)
    }
}

// MARK: - Glowing Button
struct GlowingButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Text(icon)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .serif))
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
            .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.3) : ColorTheme.accent.opacity(0.3), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Live Indicator Dot
struct LiveDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(ColorTheme.success)
            .frame(width: 8, height: 8)
            .shadow(color: ColorTheme.success.opacity(0.5), radius: 3)
            .scaleEffect(pulse ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Twinkling Star
struct TwinklingStar: View {
    let delay: Double
    @State private var opacity: Double = 0.2

    var body: some View {
        Text("✦")
            .font(.system(size: 8))
            .foregroundStyle(ColorTheme.accent)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(delay)) {
                    opacity = 0.8
                }
            }
    }
}

// MARK: - App Background
struct AppBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? ColorTheme.darkBg : ColorTheme.lightBg)
                .ignoresSafeArea()
            WoodTextureOverlay()
                .ignoresSafeArea()
        }
    }
}

// MARK: - Live Timer Bar
struct LiveTimerBar: View {
    let fraction: CGFloat
    let availableWidth: CGFloat
    let colorScheme: ColorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                .frame(height: 12)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [ColorTheme.accent, ColorTheme.neon],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(availableWidth * fraction, 0), height: 12)
                .shadow(color: colorScheme == .dark ? ColorTheme.neon.opacity(0.3) : .clear, radius: 4)
        }
        .cornerRadius(6)
    }

}

// MARK: - Category Pill
struct CategoryPill: View {
    let name: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ColorTheme.accent.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ColorTheme.accent.opacity(0.12))
            .cornerRadius(6)
    }
}
