//
//  InterstitialAdManager.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//
//
//  InterstitialAdManager.swift
//  Maryland Daily Trivia
//
//  Option A: show at most once per quiz run (no time gating)
//

import Foundation
import Combine
import GoogleMobileAds
import UIKit

@MainActor
final class InterstitialAdManager: ObservableObject {

    static let shared = InterstitialAdManager()

    @Published private(set) var isReady: Bool = false

    private var ad: InterstitialAd?
    private var isLoading: Bool = false

    // Option A: gate once per quiz run
    private var hasShownThisRun: Bool = false

    private init() {}

    /// Call at the start of every quiz run (e.g., in QuizViewModel.start()).
    func resetForNewRun() {
        hasShownThisRun = false

        // Ensure we have something preloaded by the time Q5 hits.
        if ad == nil && !isLoading {
            load()
        }
    }

    /// Preload an interstitial. Safe to call multiple times.
    func load() {
        guard !isLoading else { return }
        guard !AdMobConfig.interstitialUnitID.isEmpty else {
            #if DEBUG
            print("⚠️ Interstitial unit id missing (AdMobConfig.interstitialUnitID).")
            #endif
            return
        }

        isLoading = true
        isReady = false
        ad = nil

        let request = Request()

        InterstitialAd.load(with: AdMobConfig.interstitialUnitID, request: request) { [weak self] loadedAd, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoading = false

                if let error {
                    #if DEBUG
                    print("❌ Interstitial load failed: \(error.localizedDescription)")
                    #endif
                    self.ad = nil
                    self.isReady = false
                    return
                }

                self.ad = loadedAd
                self.isReady = (loadedAd != nil)
                #if DEBUG
                print(self.isReady ? "✅ Interstitial ready" : "⚠️ Interstitial not ready")
                #endif
            }
        }
    }

    // NOTE: presentIfReadyOncePerRun() removed — interstitial ads disabled.
}

// MARK: - Top-most VC helper
private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
