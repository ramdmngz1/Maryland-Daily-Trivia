package com.copanostudios.marylanddailytrivia.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBg
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.Error
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary

data class AppStateAction(
    val label: String,
    val enabled: Boolean = true,
    val onClick: () -> Unit
)

@Composable
fun AppLoadingState(
    title: String,
    modifier: Modifier = Modifier,
    message: String? = null
) {
    AppStateContainer(
        modifier = modifier.semantics {
            liveRegion = LiveRegionMode.Polite
            contentDescription = listOfNotNull(title, message).joinToString(". ")
        }
    ) {
        CircularProgressIndicator(color = Amber)
        Spacer(Modifier.height(16.dp))
        AppStateTitle(title)
        message?.let {
            Spacer(Modifier.height(6.dp))
            AppStateMessage(it)
        }
    }
}

@Composable
fun AppEmptyState(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    action: AppStateAction? = null
) {
    AppStateContainer(modifier = modifier) {
        Text(
            text = "No results",
            style = TextStyle(
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
                color = Amber.copy(alpha = 0.78f)
            )
        )
        Spacer(Modifier.height(10.dp))
        AppStateTitle(title)
        Spacer(Modifier.height(6.dp))
        AppStateMessage(message)
        action?.let {
            Spacer(Modifier.height(18.dp))
            AppStateButton(it)
        }
    }
}

@Composable
fun AppErrorState(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    retryCooldownSeconds: Int = 0,
    action: AppStateAction? = null
) {
    AppStateContainer(
        modifier = modifier.semantics {
            liveRegion = LiveRegionMode.Polite
            contentDescription = "$title. $message"
        }
    ) {
        Text(
            text = "!",
            modifier = Modifier
                .background(Error.copy(alpha = 0.16f), RoundedCornerShape(12.dp))
                .border(1.dp, Error.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 6.dp),
            style = TextStyle(
                fontSize = 24.sp,
                fontWeight = FontWeight.Black,
                color = Error
            )
        )
        Spacer(Modifier.height(14.dp))
        AppStateTitle(title)
        Spacer(Modifier.height(6.dp))
        AppStateMessage(message)
        if (retryCooldownSeconds > 0) {
            Spacer(Modifier.height(10.dp))
            Text(
                text = "Retrying automatically in ${retryCooldownSeconds}s",
                style = TextStyle(
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Amber
                )
            )
        }
        action?.let {
            Spacer(Modifier.height(18.dp))
            AppStateButton(it.copy(enabled = it.enabled && retryCooldownSeconds == 0))
        }
    }
}

@Composable
private fun AppStateContainer(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 420.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(CardBg.copy(alpha = 0.92f))
                .border(1.dp, CardBorder.copy(alpha = 0.8f), RoundedCornerShape(18.dp))
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            content = content
        )
    }
}

@Composable
private fun AppStateTitle(title: String) {
    Text(
        text = title,
        modifier = Modifier.semantics { heading() },
        style = TextStyle(
            fontSize = 18.sp,
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            textAlign = TextAlign.Center
        )
    )
}

@Composable
private fun AppStateMessage(message: String) {
    Text(
        text = message,
        style = TextStyle(
            fontSize = 13.sp,
            color = TextMuted,
            textAlign = TextAlign.Center,
            lineHeight = 18.sp
        )
    )
}

@Composable
private fun AppStateButton(action: AppStateAction) {
    Button(
        onClick = action.onClick,
        enabled = action.enabled,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(50),
        colors = ButtonDefaults.buttonColors(
            containerColor = Amber,
            disabledContainerColor = Amber.copy(alpha = 0.38f)
        ),
        border = BorderStroke(1.dp, Amber.copy(alpha = 0.45f)),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 12.dp)
    ) {
        Text(
            text = action.label,
            style = TextStyle(
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary.copy(alpha = if (action.enabled) 1f else 0.55f)
            )
        )
    }
}
