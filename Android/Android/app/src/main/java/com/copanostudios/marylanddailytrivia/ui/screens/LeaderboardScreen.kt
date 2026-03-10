package com.copanostudios.marylanddailytrivia.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.copanostudios.marylanddailytrivia.data.DailyLeaderboardEntry
import com.copanostudios.marylanddailytrivia.data.LeaderboardEntry
import com.copanostudios.marylanddailytrivia.ui.components.AppBackground
import com.copanostudios.marylanddailytrivia.ui.components.NeonText
import com.copanostudios.marylanddailytrivia.ui.components.WoodTextureOverlay
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.CardBg
import com.copanostudios.marylanddailytrivia.ui.theme.Error
import com.copanostudios.marylanddailytrivia.ui.theme.Warning
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary
import com.copanostudios.marylanddailytrivia.viewmodel.LeaderboardViewModel

@Composable
fun LeaderboardScreen(
    roundId: String? = null,
    leaderboardViewModel: LeaderboardViewModel = viewModel()
) {
    val leaderboard by leaderboardViewModel.leaderboard.collectAsState()
    val dailyLeaderboard by leaderboardViewModel.dailyLeaderboard.collectAsState()
    val isLoading by leaderboardViewModel.isLoading.collectAsState()
    val error by leaderboardViewModel.error.collectAsState()

    val retryCooldownSeconds by leaderboardViewModel.retryCooldownSeconds.collectAsState()
    val currentUserId = leaderboardViewModel.currentUserId
    val isDaily = roundId == null

    LaunchedEffect(roundId) {
        leaderboardViewModel.loadLeaderboard(roundId)
    }
    DisposableEffect(Unit) {
        onDispose { leaderboardViewModel.stopRefresh() }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        AppBackground()
        when {
            isLoading && leaderboard == null && dailyLeaderboard == null ->
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Amber)
                }
            error != null ->
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp)
                    ) {
                        Text("⚠", style = TextStyle(fontSize = 44.sp, color = Error.copy(alpha = 0.7f)))
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Failed to load leaderboard",
                            style = TextStyle(
                                fontSize = 17.sp,
                                fontFamily = FontFamily.Serif,
                                fontWeight = FontWeight.SemiBold,
                                color = TextPrimary
                            )
                        )
                        if (retryCooldownSeconds > 0) {
                            Spacer(Modifier.height(8.dp))
                            Text(
                                "Retrying automatically in ${retryCooldownSeconds}s",
                                style = TextStyle(
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Warning
                                )
                            )
                        }
                        Spacer(Modifier.height(16.dp))
                        androidx.compose.material3.Button(
                            onClick = { leaderboardViewModel.retryLoad() },
                            enabled = retryCooldownSeconds == 0,
                            modifier = Modifier
                                .padding(horizontal = 60.dp)
                                .fillMaxWidth()
                                .then(if (retryCooldownSeconds > 0) Modifier.then(Modifier) else Modifier),
                            colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                                containerColor = Amber,
                                disabledContainerColor = Amber.copy(alpha = 0.4f)
                            ),
                            shape = RoundedCornerShape(50)
                        ) {
                            Text(
                                "Retry",
                                style = TextStyle(
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (retryCooldownSeconds > 0) TextPrimary.copy(alpha = 0.5f) else TextPrimary
                                )
                            )
                        }
                    }
                }
            isDaily && dailyLeaderboard != null -> {
                val data = dailyLeaderboard!!
                val currentUserEntry = data.entries.firstOrNull { it.userId == currentUserId }
                Column(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .statusBarsPadding()
                            .padding(vertical = 16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        NeonText("LEADERBOARD", size = 20.sp)
                        Text(
                            "Today's Total • ${data.total} Players",
                            style = TextStyle(fontSize = 12.sp, color = TextMuted)
                        )
                        if (isLoading) {
                            CircularProgressIndicator(
                                modifier = Modifier.padding(4.dp).height(16.dp).width(16.dp),
                                color = Amber,
                                strokeWidth = 2.dp
                            )
                        }
                    }
                    // User rank pill
                    currentUserEntry?.let { entry ->
                        DailyRankPill(entry = entry, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
                    }
                    if (data.entries.size >= 3) DailyPodiumView(data.entries, currentUserId)
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(CardBg)
                    ) {
                        items(data.entries) { entry ->
                            DailyLeaderboardRow(entry, entry.userId == currentUserId)
                        }
                    }
                }
            }
            !isDaily && leaderboard != null -> {
                val data = leaderboard!!
                val currentUserEntry = data.entries.firstOrNull { it.userId == currentUserId }
                Column(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .statusBarsPadding()
                            .padding(vertical = 16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        NeonText("LEADERBOARD", size = 20.sp)
                        Text(
                            "Today's Round • ${data.total} Players",
                            style = TextStyle(fontSize = 12.sp, color = TextMuted)
                        )
                    }
                    // User rank pill
                    currentUserEntry?.let { entry ->
                        RoundRankPill(entry = entry, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
                    }
                    if (data.entries.size >= 3) PodiumView(data.entries, currentUserId)
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(CardBg)
                    ) {
                        items(data.entries) { entry ->
                            BarLeaderboardRow(entry, entry.userId == currentUserId)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Rank Pills

@Composable
private fun RoundRankPill(entry: LeaderboardEntry, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(CardBg.copy(alpha = 0.95f), RoundedCornerShape(50))
            .border(1.dp, Amber.copy(alpha = 0.35f), RoundedCornerShape(50))
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "Your Rank #${entry.rank}",
            style = TextStyle(
                fontSize = 13.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                color = Amber
            )
        )
        Spacer(Modifier.weight(1f))
        Text(
            "${entry.score} pts",
            style = TextStyle(
                fontSize = 13.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
        )
    }
}

@Composable
private fun DailyRankPill(entry: DailyLeaderboardEntry, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(CardBg.copy(alpha = 0.95f), RoundedCornerShape(50))
            .border(1.dp, Amber.copy(alpha = 0.35f), RoundedCornerShape(50))
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "Your Rank #${entry.rank}",
            style = TextStyle(
                fontSize = 13.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                color = Amber
            )
        )
        Spacer(Modifier.weight(1f))
        Text(
            "${entry.totalScore} pts",
            style = TextStyle(
                fontSize = 13.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
        )
    }
}

// MARK: - Podium Views

@Composable
private fun PodiumView(entries: List<LeaderboardEntry>, currentUserId: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        PodiumColumn(
            medal = "🥈", username = truncateName(entries[1].username),
            score = "${entries[1].score}", height = 100,
            isCurrentUser = entries[1].userId == currentUserId,
            modifier = Modifier.weight(1f)
        )
        PodiumColumn(
            medal = "🥇", username = truncateName(entries[0].username),
            score = "${entries[0].score}", height = 120,
            isCurrentUser = entries[0].userId == currentUserId,
            modifier = Modifier.weight(1f)
        )
        PodiumColumn(
            medal = "🥉", username = truncateName(entries[2].username),
            score = "${entries[2].score}", height = 85,
            isCurrentUser = entries[2].userId == currentUserId,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun DailyPodiumView(entries: List<DailyLeaderboardEntry>, currentUserId: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        PodiumColumn(
            medal = "🥈", username = truncateName(entries[1].username),
            score = "${entries[1].totalScore}", height = 100,
            isCurrentUser = entries[1].userId == currentUserId,
            extra = "${entries[1].roundsPlayed} round${if (entries[1].roundsPlayed == 1) "" else "s"}",
            modifier = Modifier.weight(1f)
        )
        PodiumColumn(
            medal = "🥇", username = truncateName(entries[0].username),
            score = "${entries[0].totalScore}", height = 120,
            isCurrentUser = entries[0].userId == currentUserId,
            extra = "${entries[0].roundsPlayed} round${if (entries[0].roundsPlayed == 1) "" else "s"}",
            modifier = Modifier.weight(1f)
        )
        PodiumColumn(
            medal = "🥉", username = truncateName(entries[2].username),
            score = "${entries[2].totalScore}", height = 85,
            isCurrentUser = entries[2].userId == currentUserId,
            extra = "${entries[2].roundsPlayed} round${if (entries[2].roundsPlayed == 1) "" else "s"}",
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun PodiumColumn(
    medal: String,
    username: String,
    score: String,
    height: Int,
    isCurrentUser: Boolean,
    extra: String? = null,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .height(height.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(CardBg),
        contentAlignment = Alignment.Center
    ) {
        WoodTextureOverlay()
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(4.dp)
        ) {
            Text(medal, style = TextStyle(fontSize = 28.sp))
            Text(
                username,
                style = TextStyle(
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isCurrentUser) Amber else TextPrimary
                ),
                maxLines = 1
            )
            Text(
                score,
                style = TextStyle(
                    fontSize = 14.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Black,
                    color = Amber
                )
            )
            extra?.let {
                Text(it, style = TextStyle(fontSize = 9.sp, color = TextMuted))
            }
        }
    }
}

// MARK: - Leaderboard Rows

@Composable
fun BarLeaderboardRow(entry: LeaderboardEntry, isCurrentUser: Boolean) {
    Box(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (isCurrentUser) Amber.copy(alpha = 0.14f) else Color.Transparent)
                .padding(start = if (isCurrentUser) 3.dp else 0.dp)
                .background(if (isCurrentUser) CardBg else Color.Transparent)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.width(36.dp)) {
                Text(
                    text = when (entry.rank) {
                        1 -> "🥇"; 2 -> "🥈"; 3 -> "🥉"
                        else -> "#${entry.rank}"
                    },
                    style = TextStyle(
                        fontSize = if (entry.rank <= 3) 18.sp else 13.sp,
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        color = TextMuted,
                        textAlign = TextAlign.Center
                    )
                )
            }
            Text(
                entry.username,
                modifier = Modifier.weight(1f),
                style = TextStyle(
                    fontSize = 15.sp,
                    fontWeight = if (isCurrentUser) FontWeight.Bold else FontWeight.Normal,
                    color = if (isCurrentUser) Amber else TextPrimary
                ),
                maxLines = 1
            )
            if (isCurrentUser) {
                Text(
                    "(you)",
                    style = TextStyle(fontSize = 10.sp, color = TextMuted),
                    modifier = Modifier.padding(end = 8.dp)
                )
            }
            Text(
                "${entry.score}",
                style = TextStyle(
                    fontSize = 15.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
        }
        // Left amber accent bar for current user
        if (isCurrentUser) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .matchParentSize()
                    .background(Amber)
            )
        }
        // Bottom divider
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(CardBorder.copy(alpha = 0.3f))
                .align(Alignment.BottomCenter)
        )
    }
}

@Composable
fun DailyLeaderboardRow(entry: DailyLeaderboardEntry, isCurrentUser: Boolean) {
    Box(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (isCurrentUser) Amber.copy(alpha = 0.14f) else Color.Transparent)
                .padding(start = if (isCurrentUser) 3.dp else 0.dp)
                .background(if (isCurrentUser) CardBg else Color.Transparent)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.width(36.dp)) {
                Text(
                    text = when (entry.rank) {
                        1 -> "🥇"; 2 -> "🥈"; 3 -> "🥉"
                        else -> "#${entry.rank}"
                    },
                    style = TextStyle(
                        fontSize = if (entry.rank <= 3) 18.sp else 13.sp,
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        color = TextMuted,
                        textAlign = TextAlign.Center
                    )
                )
            }
            // Username + rounds played subtitle
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    entry.username,
                    style = TextStyle(
                        fontSize = 15.sp,
                        fontWeight = if (isCurrentUser) FontWeight.Bold else FontWeight.Normal,
                        color = if (isCurrentUser) Amber else TextPrimary
                    ),
                    maxLines = 1
                )
                Text(
                    "${entry.roundsPlayed} round${if (entry.roundsPlayed == 1) "" else "s"}",
                    style = TextStyle(fontSize = 11.sp, color = TextMuted)
                )
            }
            // YOU badge for current user
            if (isCurrentUser) {
                Box(
                    modifier = Modifier
                        .background(Amber.copy(alpha = 0.14f), RoundedCornerShape(50))
                        .padding(horizontal = 6.dp, vertical = 3.dp)
                ) {
                    Text(
                        "YOU",
                        style = TextStyle(
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                            color = Amber
                        )
                    )
                }
                Spacer(Modifier.width(8.dp))
            }
            Text(
                "${entry.totalScore}",
                style = TextStyle(
                    fontSize = 15.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
        }
        // Left amber accent bar for current user
        if (isCurrentUser) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .matchParentSize()
                    .background(Amber)
            )
        }
        // Bottom divider
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(CardBorder.copy(alpha = 0.3f))
                .align(Alignment.BottomCenter)
        )
    }
}

private fun truncateName(name: String): String =
    if (name.length > 12) name.take(10) + "…" else name
