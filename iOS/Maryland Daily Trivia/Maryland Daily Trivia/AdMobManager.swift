//
//  AdMobManager.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//

import Foundation
import Combine
import GoogleMobileAds

@MainActor
final class AdMobManager: ObservableObject {

    static let shared = AdMobManager()

    @Published private(set) var isStarted: Bool = false

    private init() {}

    func startIfNeeded() {
        guard !isStarted else { return }

        // Newer GoogleMobileAds Swift API
        MobileAds.shared.start { status in
            Task { @MainActor in
                self.isStarted = true
                #if DEBUG
                print("✅ AdMob started: \(status.adapterStatusesByClassName.keys.count) adapters")
                #endif
            }
        }
    }
}
