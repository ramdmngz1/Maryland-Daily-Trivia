package com.copanostudios.marylanddailytrivia.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.copanostudios.marylanddailytrivia.ads.AdMobConfig
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.CardBg
import com.copanostudios.marylanddailytrivia.ui.theme.DarkBg
import com.copanostudios.marylanddailytrivia.ui.theme.NeonOrange
import com.copanostudios.marylanddailytrivia.ui.theme.Success
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary

// MARK: — Wood Texture Overlay

@Composable
fun WoodTextureOverlay(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.fillMaxSize()) {
        val woodColor = Color(0xFF8C610A)
        // Vertical grain lines every 42dp
        var x = 0f
        while (x < size.width) {
            drawLine(
                color = woodColor.copy(alpha = 0.06f),
                start = Offset(x, 0f),
                end = Offset(x, size.height),
                strokeWidth = 1f
            )
            x += 42.dp.toPx()
        }
        // Horizontal grain lines every 9dp
        var y = 0f
        while (y < size.height) {
            drawLine(
                color = woodColor.copy(alpha = 0.03f),
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = 1f
            )
            y += 9.dp.toPx()
        }
    }
}

// MARK: — App Background

@Composable
fun AppBackground(modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize().background(DarkBg)) {
        WoodTextureOverlay()
    }
}

// MARK: — App Card

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        color = CardBg,
        border = androidx.compose.foundation.BorderStroke(1.dp, CardBorder)
    ) {
        Box {
            WoodTextureOverlay(modifier = Modifier.clip(RoundedCornerShape(16.dp)))
            content()
        }
    }
}

// MARK: — Neon Text

@Composable
fun NeonText(
    text: String,
    size: TextUnit = 24.sp,
    color: Color = Amber,
    modifier: Modifier = Modifier
) {
    Text(
        text = text,
        modifier = modifier,
        style = TextStyle(
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.Black,
            fontSize = size,
            color = color,
            shadow = Shadow(
                color = NeonOrange.copy(alpha = 0.3f),
                offset = Offset(0f, 0f),
                blurRadius = 14f
            )
        )
    )
}

// MARK: — Glowing Button

@Composable
fun GlowingButton(
    text: String,
    icon: String? = null,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    val gradient = Brush.horizontalGradient(
        colors = if (enabled) listOf(Amber, NeonOrange) else listOf(Color.Gray.copy(0.4f), Color.Gray.copy(0.4f))
    )
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .shadow(
                elevation = if (enabled) 8.dp else 0.dp,
                shape = RoundedCornerShape(14.dp),
                ambientColor = NeonOrange.copy(alpha = 0.3f),
                spotColor = NeonOrange.copy(alpha = 0.3f)
            ),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        enabled = enabled,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(gradient),
            contentAlignment = Alignment.Center
        ) {
            val label = if (icon != null) "$icon $text" else text
            Text(
                text = label,
                style = TextStyle(
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    color = Color.White
                )
            )
        }
    }
}

// MARK: — Live Dot

@Composable
fun LiveDot(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "liveDot")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.3f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000),
            repeatMode = RepeatMode.Reverse
        ),
        label = "liveDotScale"
    )
    Box(
        modifier = modifier
            .scale(scale)
            .size(8.dp)
            .background(Success, CircleShape)
    )
}

// MARK: — Twinkling Star

@Composable
fun TwinklingStar(delay: Int = 0, modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "star$delay")
    val opacity by infiniteTransition.animateFloat(
        initialValue = 0.2f,
        targetValue = 0.8f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, delayMillis = delay, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "starOpacity$delay"
    )
    Text(
        text = "✦",
        modifier = modifier,
        style = TextStyle(
            fontSize = 8.sp,
            color = Amber.copy(alpha = opacity)
        )
    )
}

// MARK: — Live Timer Bar

@Composable
fun LiveTimerBar(
    fraction: Float,
    modifier: Modifier = Modifier,
    height: Dp = 12.dp
) {
    val clampedFraction = fraction.coerceIn(0f, 1f)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(6.dp))
            .background(Color.White.copy(alpha = 0.06f))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(clampedFraction)
                .height(height)
                .background(
                    Brush.horizontalGradient(listOf(Amber, NeonOrange))
                )
        )
    }
}

// MARK: — Category Pill

@Composable
fun CategoryPill(name: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(
                color = Amber.copy(alpha = 0.12f),
                shape = RoundedCornerShape(6.dp)
            )
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(
            text = name,
            style = TextStyle(
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = Amber.copy(alpha = 0.8f)
            )
        )
    }
}

// MARK: — AdMob Banner

@Composable
fun BannerAdView(modifier: Modifier = Modifier) {
    val adUnitId = AdMobConfig.bannerAdUnitId
    if (adUnitId.isBlank()) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(50.dp)
                .background(DarkBg),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Advertisement",
                style = TextStyle(fontSize = 10.sp, color = TextPrimary.copy(alpha = 0.3f))
            )
        }
        return
    }

    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp),
        factory = { context ->
            AdView(context).apply {
                setAdSize(AdSize.BANNER)
                this.adUnitId = adUnitId
                adListener = object : AdListener() {
                    override fun onAdFailedToLoad(error: LoadAdError) {
                        // Keep failure silent; placeholder/fallback UI is unnecessary here.
                    }
                }
                loadAd(AdRequest.Builder().build())
            }
        },
        update = { adView ->
            if (adView.adUnitId != adUnitId) {
                adView.adUnitId = adUnitId
                adView.loadAd(AdRequest.Builder().build())
            }
        }
    )
}
