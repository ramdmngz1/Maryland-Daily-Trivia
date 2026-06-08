//
//  AdMobConfig.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//
//
//  AdMobConfig.swift
//  Maryland Daily Trivia
//

import Foundation

enum AdMobConfig {

    // MARK: - Test Ad Unit IDs (Google-provided)
    private static let testBannerID = "ca-app-pub-3940256099942544/2934735716"
    private static let testInterstitialID = "ca-app-pub-3940256099942544/4411468910"

    // MARK: - Production Ad Unit IDs
    // Replace these with your REAL Ad Unit IDs before App Store release
    private static let prodBannerID = "REPLACE_WITH_MARYLAND_BANNER_AD_ID"
    private static let prodInterstitialID = "REPLACE_WITH_MARYLAND_INTERSTITIAL_AD_ID"

    // MARK: - Public accessors (used throughout the app)

    static let bannerAdUnitID: String = {
        #if DEBUG
        return testBannerID
        #else
        return prodBannerID
        #endif
    }()

    static let interstitialUnitID: String = {
        #if DEBUG
        return testInterstitialID
        #else
        return prodInterstitialID
        #endif
    }()
}
