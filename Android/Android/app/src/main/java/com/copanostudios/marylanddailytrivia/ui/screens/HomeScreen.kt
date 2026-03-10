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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.copanostudios.marylanddailytrivia.AppContainer
import com.copanostudios.marylanddailytrivia.ui.components.ArmadilloLogo
import com.copanostudios.marylanddailytrivia.ui.components.AppBackground
import com.copanostudios.marylanddailytrivia.ui.components.AppCard
import com.copanostudios.marylanddailytrivia.ui.components.CategoryPill
import com.copanostudios.marylanddailytrivia.ui.components.GlowingButton
import com.copanostudios.marylanddailytrivia.ui.components.LiveDot
import com.copanostudios.marylanddailytrivia.ui.components.NeonText
import com.copanostudios.marylanddailytrivia.ui.components.TwinklingStar
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBg
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.Success
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary
import com.copanostudios.marylanddailytrivia.viewmodel.HomeViewModel

@Composable
fun HomeScreen(
    onStartQuiz: () -> Unit,
    onShowSettings: () -> Unit,
    onShowLeaderboard: () -> Unit,
    homeViewModel: HomeViewModel = viewModel()
) {
    val activePlayerCount by homeViewModel.activePlayerCount.collectAsState()
    val username by homeViewModel.username.collectAsState()
    val storage = AppContainer.storage

    var showUsernameEntry by rememberSaveable { mutableStateOf(false) }
    var requiresInitialRulesFlow by rememberSaveable { mutableStateOf(false) }
    var showRulesAcknowledgement by rememberSaveable { mutableStateOf(false) }

    // On first composition, check initial state (mirrors iOS HomeView.onAppear)
    LaunchedEffect(Unit) {
        val currentUsername = storage.getOrCreateUsername()
        if (currentUsername.isEmpty()) {
            requiresInitialRulesFlow = true
            showUsernameEntry = true
            return@LaunchedEffect
        }
        requiresInitialRulesFlow = false
        if (storage.getHasPendingRules()) {
            showRulesAcknowledgement = true
            return@LaunchedEffect
        }
        // Existing user: silently acknowledge rules if not yet done
        if (!storage.getHasAcknowledgedRules()) {
            storage.setHasAcknowledgedRules(true)
        }
    }

    if (showUsernameEntry) {
        UsernameEntryScreen(
            mode = UsernameEntryMode.ONBOARDING,
            onDismiss = {
                showUsernameEntry = false
                homeViewModel.refreshUsername()
                if (requiresInitialRulesFlow) {
                    storage.setHasPendingRules(true)
                    showRulesAcknowledgement = true
                }
            }
        )
        return
    }

    if (showRulesAcknowledgement) {
        RulesAcknowledgementScreen(
            username = storage.getOrCreateUsername(),
            onAcknowledge = {
                storage.setHasAcknowledgedRules(true)
                storage.setHasPendingRules(false)
                requiresInitialRulesFlow = false
                showRulesAcknowledgement = false
            }
        )
        return
    }

    val usernameDisplay = username.ifEmpty { "Anonymous" }

    Box(modifier = Modifier.fillMaxSize()) {
        AppBackground()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 24.dp)
        ) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 20.dp)
                    .padding(top = 16.dp, bottom = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TopBarIconButton(Icons.Default.Settings, "Settings", onClick = onShowSettings)
                TopBarIconButton(Icons.Default.Star, "Leaderboard", onClick = onShowLeaderboard)
            }

            // Logo section
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 30.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    TwinklingStar(delay = 0)
                    TwinklingStar(delay = 500)
                    TwinklingStar(delay = 1000)
                    TwinklingStar(delay = 1500)
                }
                Spacer(Modifier.height(8.dp))
                ArmadilloLogo(
                    width = 240.dp,
                    modifier = Modifier.offset(y = (-6).dp)
                )
                NeonText(text = "TEXAS DAILY", size = 36.sp)
                Text(
                    text = "TRIVIA",
                    style = TextStyle(
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 4.sp,
                        color = TextMuted
                    )
                )
                Spacer(Modifier.height(16.dp))
            }

            // Username badge
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = usernameDisplay,
                    modifier = Modifier
                        .background(CardBg.copy(alpha = 0.8f), RoundedCornerShape(50))
                        .border(1.dp, CardBorder, RoundedCornerShape(50))
                        .padding(horizontal = 12.dp, vertical = 7.dp),
                    style = TextStyle(
                        fontSize = 13.sp,
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary
                    ),
                    maxLines = 1
                )
            }

            Spacer(Modifier.height(20.dp))

            // Live Contest Card
            AppCard(modifier = Modifier.padding(horizontal = 20.dp)) {
                Column(modifier = Modifier.padding(20.dp)) {
                    // Header
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                LiveDot()
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    "LIVE NOW",
                                    style = TextStyle(
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        letterSpacing = 1.sp,
                                        color = Success
                                    )
                                )
                            }
                            Text(
                                "Today's Round",
                                style = TextStyle(
                                    fontSize = 18.sp,
                                    fontFamily = FontFamily.Serif,
                                    fontWeight = FontWeight.Bold,
                                    color = TextPrimary
                                )
                            )
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Players", style = TextStyle(fontSize = 11.sp, color = TextMuted))
                            Text(
                                "$activePlayerCount",
                                style = TextStyle(
                                    fontSize = 22.sp,
                                    fontFamily = FontFamily.Serif,
                                    fontWeight = FontWeight.Bold,
                                    color = Amber
                                )
                            )
                        }
                    }

                    Spacer(Modifier.height(12.dp))

                    // Category pills
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("History", "Geography", "Culture", "Sports", "Food").forEach {
                            CategoryPill(name = it)
                        }
                    }

                    Spacer(Modifier.height(16.dp))

                    GlowingButton(text = "START QUIZ", icon = "★", onClick = onStartQuiz)
                }
            }
        }
    }
}

@Composable
private fun TopBarIconButton(icon: ImageVector, desc: String, onClick: () -> Unit) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(CardBg.copy(alpha = 0.8f))
            .border(1.dp, CardBorder, CircleShape)
    ) {
        Icon(icon, contentDescription = desc, tint = Amber, modifier = Modifier.size(20.dp))
    }
}
