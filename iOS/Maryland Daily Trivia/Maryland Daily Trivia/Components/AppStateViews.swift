import SwiftUI

struct AppStateAction {
    let title: String
    let systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }
}

struct AppLoadingStateView: View {
    let title: String
    var message: String?
    var showsSkeletonRows = true

    var body: some View {
        AppStateCard(accessibilityLabel: [title, message].compactMap { $0 }.joined(separator: ". ")) {
            if showsSkeletonRows {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.11))
                            .frame(height: 42)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(.bottom, 8)
            }

            ProgressView()
                .tint(ColorTheme.accent)
                .accessibilityLabel(title)

            AppStateText(title: title, message: message)
        }
    }
}

struct AppEmptyStateView: View {
    let title: String
    let message: String
    var action: AppStateAction?

    var body: some View {
        AppStateCard(accessibilityLabel: "\(title). \(message)") {
            Text("No results")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(ColorTheme.accent.opacity(0.8))

            AppStateText(title: title, message: message)

            if let action {
                AppStateButton(action: action)
            }
        }
    }
}

struct AppErrorStateView: View {
    let title: String
    let message: String
    var retryCooldownSeconds = 0
    var action: AppStateAction?

    var body: some View {
        AppStateCard(accessibilityLabel: "\(title). \(message)") {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ColorTheme.error)
                .accessibilityHidden(true)

            AppStateText(title: title, message: message)

            if retryCooldownSeconds > 0 {
                Text("Retrying automatically in \(retryCooldownSeconds)s")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ColorTheme.warning)
                    .monospacedDigit()
                    .accessibilityLabel("Retrying automatically in \(retryCooldownSeconds) seconds")
            }

            if let action {
                AppStateButton(
                    action: AppStateAction(
                        action.title,
                        systemImage: action.systemImage,
                        isEnabled: action.isEnabled && retryCooldownSeconds == 0,
                        action: action.action
                    )
                )
            }
        }
    }
}

private struct AppStateCard<Content: View>: View {
    let accessibilityLabel: String
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(accessibilityLabel: String, @ViewBuilder content: () -> Content) {
        self.accessibilityLabel = accessibilityLabel
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 14) {
            content
        }
        .padding(24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.46 : 0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct AppStateText: View {
    let title: String
    let message: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.86)
            }
        }
    }
}

private struct AppStateButton: View {
    let action: AppStateAction

    var body: some View {
        Button(action: action.action) {
            Label {
                Text(action.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            } icon: {
                if let systemImage = action.systemImage {
                    Image(systemName: systemImage)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            Capsule()
                .fill(action.isEnabled ? ColorTheme.accent : ColorTheme.accent.opacity(0.35))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .disabled(!action.isEnabled)
        .accessibilityHint(action.isEnabled ? "Activates \(action.title)" : "Temporarily unavailable")
    }
}
