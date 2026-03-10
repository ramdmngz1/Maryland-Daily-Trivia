package com.copanostudios.marylanddailytrivia.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

// Force dark theme — matches iOS .preferredColorScheme(.dark)
private val AppColorScheme = darkColorScheme(
    primary = Amber,
    onPrimary = DarkBg,
    secondary = WarmTan,
    onSecondary = DarkBg,
    tertiary = NeonOrange,
    background = DarkBg,
    onBackground = TextPrimary,
    surface = CardBg,
    onSurface = TextPrimary,
    surfaceVariant = AppSurface,
    onSurfaceVariant = TextSecondary,
    outline = CardBorder,
    error = Error,
    onError = DarkBg
)

@Composable
fun MarylandDailyTriviaTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = AppColorScheme,
        typography = Typography,
        content = content
    )
}
