//
//  ColorTheme.swift
//  Maryland Daily Trivia
//
//  Maryland flag color palette:
//  Calvert arms: Gold (#C8A84B) and Black
//  Crossland arms: Red (#CC1433) and White
//

import SwiftUI

enum ColorTheme {
    // MARK: - Primary Brand Colors (Maryland Red + Gold skin)
    static let primary   = Color(red: 0.78, green: 0.14, blue: 0.19)  // Warm Maryland red
    static let secondary = Color(red: 0.84, green: 0.67, blue: 0.25)  // Maryland gold
    static let accent    = Color(red: 0.94, green: 0.76, blue: 0.22)  // Primary UI accent (gold)

    // MARK: - Neon Accent (gold glow)
    static let neon = Color(red: 1.0, green: 0.88, blue: 0.32)        // Soft bright gold

    // MARK: - Background Colors (creme backdrop + dark panels)
    static let darkBg       = Color(red: 0.96, green: 0.92, blue: 0.85)    // Light creme
    static let cardBg       = Color(red: 0.10, green: 0.06, blue: 0.07)    // Deep warm charcoal
    static let cardBgHover  = Color(red: 0.15, green: 0.10, blue: 0.11)    // Raised panel tone
    static let appSurface   = Color(red: 0.11, green: 0.07, blue: 0.08)    // Status/nav surface
    static let cardBorder   = Color(red: 0.39, green: 0.33, blue: 0.29)    // Warm border

    // MARK: - Light mode equivalents
    static let lightBg      = Color(red: 0.980, green: 0.961, blue: 0.953) // #FAF5F3
    static let lightCard    = Color(red: 1.0,   green: 1.0,   blue: 1.0)
    static let lightSurface = Color(red: 0.957, green: 0.929, blue: 0.918) // #F4EEEA
    static let lightBorder  = Color(red: 0.875, green: 0.800, blue: 0.780) // #DFCCC7

    // MARK: - Adaptive helpers
    static let subtleBackground = Color(red: 0.980, green: 0.961, blue: 0.953)
    static let cardBackground   = Color(.systemBackground)

    // MARK: - Text Colors
    static let textPrimary   = Color(red: 0.97, green: 0.94, blue: 0.90)
    static let textSecondary = Color(red: 0.80, green: 0.73, blue: 0.67)
    static let textMuted     = Color(red: 0.63, green: 0.55, blue: 0.49)

    // MARK: - Semantic Colors
    static let success = Color(red: 0.29,  green: 0.87,  blue: 0.50)   // #4ADE80
    static let error   = Color(red: 0.937, green: 0.267, blue: 0.267)  // #EF4444
    static let warning = Color(red: 0.96,  green: 0.75,  blue: 0.10)   // #F5BF1A

    // MARK: - Category Colors
    static let history   = Color(red: 0.647, green: 0.365, blue: 0.294)
    static let geography = Color(red: 0.298, green: 0.686, blue: 0.314)
    static let sports    = Color(red: 0.204, green: 0.596, blue: 0.859)
    static let culture   = Color(red: 0.686, green: 0.322, blue: 0.871)
    static let food      = Color.orange
    static let nature    = Color.mint
    static let weather   = Color.cyan

    // MARK: - Timer Colors
    static let timerGreen  = Color(red: 0.29,  green: 0.87,  blue: 0.50)
    static let timerOrange = Color(red: 0.96,  green: 0.75,  blue: 0.10)
    static let timerRed    = Color(red: 0.937, green: 0.267, blue: 0.267)

    // MARK: - Answer Button Colors
    static let answerDefault          = Color(red: 0.94,  green: 0.76,  blue: 0.22)   // Maryland Gold
    static let answerCorrect          = Color(red: 0.29,  green: 0.87,  blue: 0.50)
    static let answerIncorrect        = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let answerSand             = Color(red: 0.992, green: 0.961, blue: 0.941)  // warm cream
    static let answerSandSelected     = Color(red: 0.980, green: 0.937, blue: 0.902)
    static let answerSandDark         = Color(red: 0.290, green: 0.118, blue: 0.157)  // dark maroon
    static let answerSandDarkSelected = Color(red: 0.361, green: 0.157, blue: 0.196)

    // MARK: - Progress Bar (Red → Gold)
    static let progressStart = Color(red: 0.78, green: 0.14, blue: 0.19) // Maryland Red
    static let progressEnd   = Color(red: 1.0,  green: 0.88, blue: 0.32) // Gold
}

// MARK: - Legacy Support
enum AppColor {
    static let background    = ColorTheme.subtleBackground
    static let card          = ColorTheme.cardBackground
    static let primary       = ColorTheme.accent
    static let secondary     = ColorTheme.secondary
    static let accent        = ColorTheme.accent
    static let textPrimary   = ColorTheme.textPrimary
    static let textSecondary = ColorTheme.textSecondary
    static let divider       = Color.secondary.opacity(0.2)
}
