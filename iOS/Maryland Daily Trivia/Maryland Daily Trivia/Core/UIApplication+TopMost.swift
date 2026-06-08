//
//  UIApplication+TopMost.swift
//  Maryland Daily Trivia
//
//  Created by Ramon Dominguez on 1/2/26.
//
//
//  UIApplication+TopMost.swift
//  Maryland Daily Trivia
//

import UIKit

extension UIApplication {

    static func topMostViewController(
        base: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    ) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}
