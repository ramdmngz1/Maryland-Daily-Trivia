import SwiftUI

// Overlay to obscure app content when not active (e.g., app switcher)
struct PrivacyBlur: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var shouldObscure = false

    func body(content: Content) -> some View {
        ZStack {
            content
            if shouldObscure {
                Color.black.opacity(0.6)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    )
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            shouldObscure = (newPhase != .active)
        }
    }
}

extension View {
    func privacyBlur() -> some View { modifier(PrivacyBlur()) }
}
