package com.copanostudios.marylanddailytrivia.ui.theme

import androidx.compose.ui.graphics.Color

// Maryland flag palette:
// Calvert arms: Gold (#C8A84B) and Black
// Crossland arms: Red (#CC1433) and White

// MARK: — Primary Brand Colors (Maryland)
val MarylandRed  = Color(0xFFCC1433)   // Crossland Red
val MarylandGold = Color(0xFFC8A84B)   // Calvert Gold
val BrightGold   = Color(0xFFFFD700)   // Neon gold glow

// MARK: — Background Colors (dark — near-black with warm red undertone)
val DarkBg      = Color(0xFF0D0305)
val CardBg      = Color(0xFF1F0A0D)
val CardBgHover = Color(0xFF2D0F14)
val AppSurface  = Color(0xFF150408)
val CardBorder  = Color(0xFF3D151C)

// MARK: — Light mode
val LightBg      = Color(0xFFFAF5F3)
val LightCard    = Color(0xFFFFFFFF)
val LightSurface = Color(0xFFF4EEEA)
val LightBorder  = Color(0xFFDFCCC7)

// MARK: — Text Colors
val TextPrimary   = Color(0xFFF7EDE5)
val TextSecondary = Color(0xFFC4A0A8)
val TextMuted     = Color(0xFF7A565F)

// MARK: — Semantic Colors
val Success = Color(0xFF4ADE80)
val Error   = Color(0xFFEF4444)
val Warning = Color(0xFFF5BF1A)

// MARK: — Timer Colors
val TimerGreen  = Color(0xFF4ADE80)
val TimerOrange = Color(0xFFF5BF1A)
val TimerRed    = Color(0xFFEF4444)

// MARK: — Answer Button Colors
val AnswerDefault          = Color(0xFFCC1433)   // Maryland Red
val AnswerCorrect          = Color(0xFF4ADE80)
val AnswerIncorrect        = Color(0xFFEF4444)
val AnswerSand             = Color(0xFFFDF5F0)
val AnswerSandSelected     = Color(0xFFFAEFE6)
val AnswerSandDark         = Color(0xFF4A1E28)
val AnswerSandDarkSelected = Color(0xFF5C2432)

// Legacy aliases (used by existing Compose code)
val Amber      = MarylandRed
val WarmTan    = MarylandGold
val NeonOrange = BrightGold
