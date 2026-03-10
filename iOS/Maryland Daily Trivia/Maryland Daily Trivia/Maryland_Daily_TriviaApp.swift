//
//  Maryland_Daily_TriviaApp.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//  Updated: 1/16/26 - Removed GameCenter, contest-only mode
//

import SwiftUI
import AppTrackingTransparency

@main
struct Maryland_Daily_TriviaApp: App {
    init() {
        AppPreferences.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Authenticate early so tokens are ready before first API call
                    do {
                        try await AppAttestManager.shared.ensureAuthenticated()
                        #if DEBUG
                        print("[AppAttest] Authenticated successfully")
                        #endif
                    } catch {
                        #if DEBUG
                        print("[AppAttest] Authentication failed:", error.localizedDescription)
                        #endif
                    }

                    // Request ATT consent before initializing ads
                    _ = await ATTrackingManager.requestTrackingAuthorization()
                    AdMobManager.shared.startIfNeeded()
                    InterstitialAdManager.shared.load()
                }
        }
    }
}
