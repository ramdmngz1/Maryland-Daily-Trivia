package com.copanostudios.marylanddailytrivia.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.copanostudios.marylanddailytrivia.R
import kotlinx.coroutines.delay

// Blue crab walking animation frames
// Asset names: crab_walk_01 ... crab_walk_08
private val CrabFrames = listOf(
    R.drawable.crab_walk_01,
    R.drawable.crab_walk_02,
    R.drawable.crab_walk_03,
    R.drawable.crab_walk_04,
    R.drawable.crab_walk_05,
    R.drawable.crab_walk_06,
    R.drawable.crab_walk_07,
    R.drawable.crab_walk_08
)

@Composable
fun BlueCrabSprite(
    modifier: Modifier = Modifier,
    size: Dp = 160.dp
) {
    var frameIndex by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(95L)
            frameIndex = (frameIndex + 1) % CrabFrames.size
        }
    }

    Image(
        painter = painterResource(id = CrabFrames[frameIndex]),
        contentDescription = "Blue crab mascot",
        contentScale = ContentScale.Fit,
        modifier = modifier.size(size)
    )
}

@Composable
fun BlueCrabLogo(
    modifier: Modifier = Modifier,
    width: Dp = 220.dp
) {
    Image(
        painter = painterResource(id = R.drawable.crab_logo),
        contentDescription = "Blue crab logo",
        contentScale = ContentScale.Fit,
        modifier = modifier
            .width(width)
            .aspectRatio(805f / 455f)
    )
}

// Backward-compat aliases — callers using old names compile without changes
@Composable
fun ArmadilloSprite(modifier: Modifier = Modifier, size: Dp = 160.dp) =
    BlueCrabSprite(modifier = modifier, size = size)

@Composable
fun ArmadilloLogo(modifier: Modifier = Modifier, width: Dp = 220.dp) =
    BlueCrabLogo(modifier = modifier, width = width)
