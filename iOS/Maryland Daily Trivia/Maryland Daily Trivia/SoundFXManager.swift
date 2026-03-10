//
//  SoundFXManager.swift
//  Maryland Daily Trivia
//

import Foundation
import AudioToolbox

enum SoundFXManager {
    private static func play(_ soundId: SystemSoundID) {
        AudioServicesPlaySystemSound(soundId)
    }

    static func tap() {
        play(1104)
    }

    static func selection() {
        play(1105)
    }

    static func success() {
        play(1113)
    }

    static func error() {
        play(1053)
    }

    static func warning() {
        play(1057)
    }
}
