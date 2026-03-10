package com.copanostudios.marylanddailytrivia.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.copanostudios.marylanddailytrivia.AppContainer
import com.copanostudios.marylanddailytrivia.ui.components.ArmadilloLogo
import com.copanostudios.marylanddailytrivia.ui.components.AppBackground
import com.copanostudios.marylanddailytrivia.ui.components.GlowingButton
import com.copanostudios.marylanddailytrivia.ui.components.NeonText
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBg
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary
import com.copanostudios.marylanddailytrivia.ui.theme.Warning

enum class UsernameEntryMode { ONBOARDING, EDITING }

@Composable
fun UsernameEntryScreen(
    mode: UsernameEntryMode = UsernameEntryMode.ONBOARDING,
    onDismiss: () -> Unit
) {
    val storage = AppContainer.storage
    var inputName by remember { mutableStateOf("") }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    val titleText = when (mode) {
        UsernameEntryMode.ONBOARDING -> "Welcome, partner!"
        UsernameEntryMode.EDITING -> "Edit Your Name"
    }
    val subtitleText = when (mode) {
        UsernameEntryMode.ONBOARDING -> "Enter your name to compete on the live leaderboard"
        UsernameEntryMode.EDITING -> "Update the name shown for you on the leaderboard"
    }
    val buttonText = when (mode) {
        UsernameEntryMode.ONBOARDING -> "START PLAYING"
        UsernameEntryMode.EDITING -> "SAVE NAME"
    }
    val fieldPrompt = when (mode) {
        UsernameEntryMode.ONBOARDING -> "Enter your name"
        UsernameEntryMode.EDITING -> "Update your name"
    }

    Box(modifier = Modifier.fillMaxSize()) {
        AppBackground()

        // Close button for editing mode
        if (mode == UsernameEntryMode.EDITING) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .statusBarsPadding()
                    .padding(top = 8.dp, end = 20.dp)
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(CardBg.copy(alpha = 0.9f))
                    .border(1.dp, CardBorder, CircleShape)
                    .clickable { onDismiss() },
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = Amber, modifier = Modifier.size(16.dp))
            }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.weight(0.5f))

            ArmadilloLogo(width = 112.dp)
            NeonText("TEXAS DAILY", size = 24.sp)
            Text(
                "TRIVIA",
                style = TextStyle(
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 4.sp,
                    color = TextMuted
                )
            )

            Spacer(Modifier.height(32.dp))

            Text(
                titleText,
                style = TextStyle(
                    fontSize = 22.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
            Spacer(Modifier.height(8.dp))
            Text(
                subtitleText,
                style = TextStyle(
                    fontSize = 14.sp,
                    color = TextMuted,
                    textAlign = TextAlign.Center
                )
            )

            Spacer(Modifier.height(32.dp))

            // Input field
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    "YOUR NAME",
                    modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
                    style = TextStyle(
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp,
                        color = TextMuted
                    )
                )
                OutlinedTextField(
                    value = inputName,
                    onValueChange = { if (it.length <= 20) inputName = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(focusRequester),
                    placeholder = {
                        Text(
                            fieldPrompt,
                            style = TextStyle(color = TextMuted.copy(alpha = 0.6f))
                        )
                    },
                    textStyle = TextStyle(
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextPrimary
                    ),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Amber,
                        unfocusedBorderColor = CardBorder,
                        focusedContainerColor = CardBg,
                        unfocusedContainerColor = CardBg,
                        cursorColor = Amber
                    ),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = {
                        val cleaned = sanitize(inputName)
                        if (cleaned.isNotEmpty() && cleaned != "Anonymous") {
                            storage.saveUsername(cleaned)
                            onDismiss()
                        }
                    })
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    Spacer(Modifier.weight(1f))
                    Text(
                        "${inputName.length}/20",
                        modifier = Modifier.padding(top = 4.dp, end = 4.dp),
                        style = TextStyle(
                            fontSize = 11.sp,
                            color = if (inputName.length >= 20) Warning else TextMuted,
                            textAlign = TextAlign.End
                        )
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            val sanitized = sanitize(inputName)
            val isEnabled = sanitized.isNotEmpty() && sanitized != "Anonymous"

            GlowingButton(
                text = buttonText,
                icon = "★",
                enabled = isEnabled,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (isEnabled) {
                    storage.saveUsername(sanitized)
                    onDismiss()
                }
            }

            Spacer(Modifier.weight(1f))
        }
    }
}

/** Sanitize username: alphanumeric + space + -_.  max 20 chars */
private fun sanitize(raw: String): String {
    val allowed = Regex("[^a-zA-Z0-9 \\-_.]")
    val filtered = raw.trim().replace(allowed, " ")
    val collapsed = filtered.replace(Regex("\\s+"), " ").trim()
    val capped = if (collapsed.length > 20) collapsed.take(20) else collapsed
    return capped
}
