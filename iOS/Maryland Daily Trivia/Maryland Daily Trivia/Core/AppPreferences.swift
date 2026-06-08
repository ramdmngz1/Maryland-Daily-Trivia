//
//  AppPreferences.swift
//  Maryland Daily Trivia
//

import Foundation

enum AppPreferences {
    static let hapticsEnabledKey = "pref_haptics_enabled_v1"
    static let reduceMotionKey = "pref_reduce_motion_v1"
    static let hasSeenLiveCoachMarksKey = "has_seen_live_coach_marks_v1"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            hapticsEnabledKey: true,
            reduceMotionKey: false,
            hasSeenLiveCoachMarksKey: false
        ])
    }

    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsEnabledKey) as? Bool ?? true
    }

    static var reduceMotionEnabled: Bool {
        UserDefaults.standard.object(forKey: reduceMotionKey) as? Bool ?? false
    }
}
