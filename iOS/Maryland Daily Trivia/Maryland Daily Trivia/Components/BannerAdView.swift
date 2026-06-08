//
//  BannerAdView.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/1/26.
//

import SwiftUI
import UIKit
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {

    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.topMostViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // no-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            // Optional: print("✅ Banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("❌ Banner failed: \(error.localizedDescription)")
            #endif
        }
    }
}
