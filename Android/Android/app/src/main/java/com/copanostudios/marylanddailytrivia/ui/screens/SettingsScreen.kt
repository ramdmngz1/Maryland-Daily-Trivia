package com.copanostudios.marylanddailytrivia.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.copanostudios.marylanddailytrivia.AppContainer
import com.copanostudios.marylanddailytrivia.BuildConfig
import com.copanostudios.marylanddailytrivia.data.TriviaRules
import com.copanostudios.marylanddailytrivia.ui.components.AppBackground
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBg
import com.copanostudios.marylanddailytrivia.ui.theme.CardBgHover
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.NeonOrange
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary
import com.copanostudios.marylanddailytrivia.ui.theme.TextSecondary

@Composable
fun SettingsScreen(onDismiss: () -> Unit) {
    val storage = AppContainer.storage
    var username by remember { mutableStateOf(storage.getOrCreateUsername().ifEmpty { "Anonymous" }) }
    var showUsernameEntry by remember { mutableStateOf(false) }
    var hapticsEnabled by remember { mutableStateOf(storage.getHapticsEnabled()) }
    var reduceMotionEnabled by remember { mutableStateOf(storage.getReduceMotionEnabled()) }
    val context = LocalContext.current

    if (showUsernameEntry) {
        UsernameEntryScreen(
            mode = UsernameEntryMode.EDITING,
            onDismiss = {
                showUsernameEntry = false
                username = storage.getOrCreateUsername().ifEmpty { "Anonymous" }
            }
        )
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        AppBackground()
        Column(modifier = Modifier.fillMaxSize()) {
            // Title bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Spacer(Modifier.weight(1f))
                Text(
                    "Settings",
                    style = TextStyle(
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Amber
                    )
                )
                Spacer(Modifier.weight(1f))
                // Gradient Done button (matches iOS toolbar trailing)
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .shadow(4.dp, RoundedCornerShape(50), spotColor = NeonOrange.copy(0.2f))
                        .background(
                            Brush.linearGradient(
                                listOf(Amber.copy(alpha = 0.92f), NeonOrange.copy(alpha = 0.85f))
                            ),
                            RoundedCornerShape(50)
                        )
                        .border(1.dp, Amber.copy(alpha = 0.42f), RoundedCornerShape(50))
                        .clickable { onDismiss() }
                        .padding(horizontal = 20.dp, vertical = 11.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "Done",
                        style = TextStyle(
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = TextPrimary
                        )
                    )
                }
            }

            // Scrollable content
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 14.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                // PROFILE section
                SettingsSectionHeader("PROFILE")
                SettingsCard {
                    ValueRow(
                        icon = Icons.Default.AccountCircle,
                        label = "Username",
                        value = username,
                        valueFontFamily = FontFamily.Serif,
                        valueFontWeight = FontWeight.SemiBold
                    )
                    SettingsDivider()
                    ActionRow(
                        icon = Icons.Default.Edit,
                        label = "Change Username",
                        labelColor = Amber,
                        onClick = { showUsernameEntry = true }
                    )
                }

                // EXPERIENCE section
                SettingsSectionHeader("EXPERIENCE")
                SettingsCard {
                    ToggleRow(
                        icon = "📳",
                        label = "Haptics",
                        checked = hapticsEnabled,
                        onCheckedChange = {
                            hapticsEnabled = it
                            storage.setHapticsEnabled(it)
                        }
                    )
                    SettingsDivider()
                    ToggleRow(
                        icon = "🚶",
                        label = "Reduce Motion",
                        checked = reduceMotionEnabled,
                        onCheckedChange = {
                            reduceMotionEnabled = it
                            storage.setReduceMotionEnabled(it)
                        }
                    )
                }
                Text(
                    "Reduce Motion applies in addition to system accessibility settings.",
                    style = TextStyle(fontSize = 12.sp, color = TextMuted),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp)
                )

                // ABOUT section
                SettingsSectionHeader("ABOUT")
                SettingsCard {
                    ValueRow(
                        icon = Icons.Default.Info,
                        label = "Version",
                        value = BuildConfig.VERSION_NAME
                    )
                    SettingsDivider()
                    LinkRow(
                        icon = "🔒",
                        label = "Privacy Policy",
                        onClick = {
                            context.startActivity(
                                Intent(Intent.ACTION_VIEW,
                                    Uri.parse("https://www.copanostudios.com/privacy-texas-daily-trivia"))
                            )
                        }
                    )
                    SettingsDivider()
                    LinkRow(
                        icon = "❓",
                        label = "Support",
                        onClick = {
                            context.startActivity(
                                Intent(Intent.ACTION_VIEW,
                                    Uri.parse("https://www.copanostudios.com/support-texas-daily-trivia"))
                            )
                        }
                    )
                    SettingsDivider()
                    Text(
                        "© 2026 Copano Studios. Not affiliated with the State of Maryland.",
                        style = TextStyle(fontSize = 10.5.sp, color = TextSecondary),
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 14.dp)
                    )
                }

                // HOW IT WORKS section
                SettingsSectionHeader("HOW IT WORKS")
                SettingsCard {
                    TriviaRules.items.forEachIndexed { index, rule ->
                        HowItWorksRow(index = index, rule = rule)
                        if (index < TriviaRules.items.size - 1) {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Section Header

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        text = title,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 2.dp),
        style = TextStyle(
            fontSize = 12.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 3.sp,
            color = Amber
        )
    )
}

// MARK: - Settings Card

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(28.dp),
                spotColor = NeonOrange.copy(alpha = 0.12f),
                ambientColor = NeonOrange.copy(alpha = 0.06f)
            )
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.linearGradient(
                    listOf(
                        CardBgHover.copy(alpha = 0.94f),
                        CardBg.copy(alpha = 0.98f)
                    )
                )
            )
            .border(1.dp, Amber.copy(alpha = 0.26f), RoundedCornerShape(28.dp))
            .padding(vertical = 8.dp)
    ) {
        Column { content() }
    }
}

// MARK: - Row Divider

@Composable
private fun SettingsDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(start = 56.dp, end = 12.dp),
        thickness = 1.dp,
        color = CardBorder.copy(alpha = 0.75f)
    )
}

// MARK: - Value Row

@Composable
private fun ValueRow(
    icon: ImageVector,
    label: String,
    value: String,
    valueFontFamily: FontFamily = FontFamily.Default,
    valueFontWeight: FontWeight = FontWeight.Medium
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.size(28.dp), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = Amber, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = TextStyle(fontSize = 15.sp, color = TextPrimary)
        )
        Text(
            value,
            style = TextStyle(
                fontSize = 15.sp,
                fontFamily = valueFontFamily,
                fontWeight = valueFontWeight,
                color = Amber
            )
        )
    }
}

// MARK: - Action Row

@Composable
private fun ActionRow(
    icon: ImageVector,
    label: String,
    labelColor: Color = TextPrimary,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.size(28.dp), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = Amber, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            style = TextStyle(
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = labelColor
            )
        )
    }
}

// MARK: - Toggle Row

@Composable
private fun ToggleRow(
    icon: String,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.size(28.dp), contentAlignment = Alignment.Center) {
            Text(icon, style = TextStyle(fontSize = 18.sp))
        }
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = TextStyle(fontSize = 15.sp, color = TextPrimary)
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Amber,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = CardBorder
            )
        )
    }
}

// MARK: - Link Row

@Composable
private fun LinkRow(
    icon: String,
    label: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.size(28.dp), contentAlignment = Alignment.Center) {
            Text(icon, style = TextStyle(fontSize = 18.sp))
        }
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = TextStyle(fontSize = 15.sp, color = TextPrimary)
        )
        Text(
            "↗",
            style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Amber)
        )
    }
}

// MARK: - How It Works Row

@Composable
private fun HowItWorksRow(index: Int, rule: com.copanostudios.marylanddailytrivia.data.TriviaRule) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.Top
    ) {
        // Numbered badge
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(Amber.copy(alpha = 0.16f))
                .border(1.dp, Amber.copy(alpha = 0.45f), RoundedCornerShape(50))
                .padding(horizontal = 8.dp, vertical = 5.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "${index + 1}",
                style = TextStyle(
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = Amber
                )
            )
        }
        Spacer(Modifier.width(12.dp))
        Column {
            Text(
                rule.title,
                style = TextStyle(
                    fontSize = 16.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
            Spacer(Modifier.height(4.dp))
            Text(
                rule.detail,
                style = TextStyle(fontSize = 13.sp, color = TextSecondary)
            )
        }
    }
}
