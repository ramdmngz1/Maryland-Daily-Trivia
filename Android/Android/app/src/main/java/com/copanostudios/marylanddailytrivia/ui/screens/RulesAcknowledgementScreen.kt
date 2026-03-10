package com.copanostudios.marylanddailytrivia.ui.screens

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.copanostudios.marylanddailytrivia.data.TriviaRule
import com.copanostudios.marylanddailytrivia.data.TriviaRules
import com.copanostudios.marylanddailytrivia.ui.components.AppBackground
import com.copanostudios.marylanddailytrivia.ui.components.AppCard
import com.copanostudios.marylanddailytrivia.ui.components.GlowingButton
import com.copanostudios.marylanddailytrivia.ui.components.NeonText
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary
import com.copanostudios.marylanddailytrivia.ui.theme.TextSecondary

@Composable
fun RulesAcknowledgementScreen(
    username: String,
    onAcknowledge: () -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {
        AppBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .statusBarsPadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = 96.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(20.dp))

            NeonText("WELCOME", size = 26.sp)
            Spacer(Modifier.height(8.dp))
            Text(
                username.ifEmpty { "Player" },
                style = TextStyle(
                    fontSize = 22.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Please review the rules before your first round.",
                style = TextStyle(
                    fontSize = 14.sp,
                    color = TextMuted,
                    textAlign = TextAlign.Center
                ),
                modifier = Modifier.padding(horizontal = 20.dp)
            )

            Spacer(Modifier.height(16.dp))

            AppCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        "HOW IT WORKS",
                        style = TextStyle(
                            fontSize = 13.sp,
                            fontFamily = FontFamily.Serif,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 2.sp,
                            color = Amber
                        )
                    )
                    Spacer(Modifier.height(16.dp))
                    TriviaRules.items.forEachIndexed { index, rule ->
                        RuleRow(rule)
                        if (index < TriviaRules.items.size - 1) {
                            HorizontalDivider(
                                modifier = Modifier.padding(vertical = 4.dp),
                                thickness = 1.dp,
                                color = CardBorder.copy(alpha = 0.4f)
                            )
                        }
                    }
                }
            }
        }

        // Pinned OK button at bottom
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(horizontal = 20.dp, vertical = 16.dp)
        ) {
            GlowingButton(
                text = "OK, I Understand",
                modifier = Modifier.fillMaxWidth(),
                onClick = onAcknowledge
            )
        }
    }
}

@Composable
private fun RuleRow(rule: TriviaRule) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(rule.icon, style = TextStyle(fontSize = 16.sp), modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(12.dp))
        Column {
            Text(
                rule.title,
                style = TextStyle(
                    fontSize = 14.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
            Spacer(Modifier.height(3.dp))
            Text(
                rule.detail,
                style = TextStyle(fontSize = 12.sp, color = TextSecondary)
            )
        }
    }
}
