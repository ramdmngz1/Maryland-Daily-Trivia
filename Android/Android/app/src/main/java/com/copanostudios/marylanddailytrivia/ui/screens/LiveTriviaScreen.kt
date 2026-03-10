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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import kotlinx.coroutines.isActive
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.copanostudios.marylanddailytrivia.core.Scoring
import com.copanostudios.marylanddailytrivia.data.LiveTriviaState
import com.copanostudios.marylanddailytrivia.data.Phase
import com.copanostudios.marylanddailytrivia.ui.components.ArmadilloLogo
import com.copanostudios.marylanddailytrivia.ui.components.AppBackground
import com.copanostudios.marylanddailytrivia.ui.components.AppCard
import com.copanostudios.marylanddailytrivia.ui.components.BannerAdView
import com.copanostudios.marylanddailytrivia.ui.components.CategoryPill
import com.copanostudios.marylanddailytrivia.ui.components.GlowingButton
import com.copanostudios.marylanddailytrivia.ui.components.LiveDot
import com.copanostudios.marylanddailytrivia.ui.components.LiveTimerBar
import com.copanostudios.marylanddailytrivia.ui.components.NeonText
import com.copanostudios.marylanddailytrivia.ui.theme.Amber
import com.copanostudios.marylanddailytrivia.ui.theme.CardBorder
import com.copanostudios.marylanddailytrivia.ui.theme.AppSurface
import com.copanostudios.marylanddailytrivia.ui.theme.Error
import com.copanostudios.marylanddailytrivia.ui.theme.Success
import com.copanostudios.marylanddailytrivia.ui.theme.TextMuted
import com.copanostudios.marylanddailytrivia.ui.theme.TextPrimary
import com.copanostudios.marylanddailytrivia.ui.theme.TextSecondary
import com.copanostudios.marylanddailytrivia.ui.theme.Warning
import com.copanostudios.marylanddailytrivia.viewmodel.LiveTriviaViewModel
import kotlinx.coroutines.delay

@Composable
fun LiveTriviaScreen(
    onExit: () -> Unit,
    liveViewModel: LiveTriviaViewModel = viewModel()
) {
    val liveState by liveViewModel.liveState.collectAsState()
    val localPhase by liveViewModel.localPhase.collectAsState()
    val localQuestionIndex by liveViewModel.localQuestionIndex.collectAsState()
    val localSecondsRemaining by liveViewModel.localSecondsRemaining.collectAsState()
    val eliminatedIndices by liveViewModel.eliminatedIndices.collectAsState()
    val currentQuestions by liveViewModel.currentQuestions.collectAsState()
    val userSession by liveViewModel.userSession.collectAsState()
    val error by liveViewModel.error.collectAsState()

    // Join-wait logic: if joining mid-question, show countdown to next question
    var showJoinWait by remember { mutableStateOf(false) }
    var joinWaitTargetMs by remember { mutableStateOf(0L) }
    var joinWaitQuestionIndex by remember { mutableStateOf(-1) }
    var hasCheckedJoin by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        liveViewModel.startSync()
        onDispose { liveViewModel.stopSync() }
    }

    // Check join-wait once when first state arrives
    LaunchedEffect(liveState) {
        val state = liveState ?: return@LaunchedEffect
        if (!hasCheckedJoin) {
            hasCheckedJoin = true
            if (liveViewModel.isLocallyInQuiz &&
                (localPhase == Phase.QUESTION || localPhase == Phase.EXPLANATION)) {
                val nextStart = state.roundStartTimeMs +
                        ((localQuestionIndex + 1) * LiveTriviaState.QUESTION_CYCLE * 1000).toLong()
                joinWaitTargetMs = nextStart
                joinWaitQuestionIndex = localQuestionIndex + 1
                showJoinWait = true
            }
        }
    }

    // Dismiss join-wait when target question starts
    LaunchedEffect(localQuestionIndex, localPhase) {
        if (showJoinWait &&
            liveViewModel.isLocallyInQuiz &&
            localPhase == Phase.QUESTION &&
            localQuestionIndex >= joinWaitQuestionIndex) {
            showJoinWait = false
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(com.copanostudios.marylanddailytrivia.ui.theme.DarkBg)) {
        // Top bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            val sideSlotWidth = 108.dp

            Box(modifier = Modifier.fillMaxWidth()) {
                Box(
                    modifier = Modifier
                        .width(sideSlotWidth)
                        .align(Alignment.CenterStart),
                    contentAlignment = Alignment.CenterStart
                ) {
                    IconButton(onClick = {
                        liveViewModel.stopSync()
                        onExit()
                    }, modifier = Modifier.size(40.dp)) {
                        Icon(Icons.Default.Close, "Exit", tint = Amber)
                    }
                }

                Box(
                    modifier = Modifier
                        .width(sideSlotWidth)
                        .align(Alignment.CenterEnd),
                    contentAlignment = Alignment.CenterEnd
                ) {
                    // Status right side
                    liveState?.let { state ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (liveViewModel.isLocallyInQuiz) {
                                Text(
                                    "Q${localQuestionIndex + 1}/10",
                                    style = TextStyle(
                                        fontSize = 14.sp,
                                        fontFamily = FontFamily.Serif,
                                        fontWeight = FontWeight.Bold,
                                        color = Amber
                                    )
                                )
                            }
                            Spacer(Modifier.width(8.dp))
                            LiveDot()
                            Spacer(Modifier.width(4.dp))
                            Text(
                                "${state.activePlayerCount}",
                                style = TextStyle(fontSize = 12.sp, color = TextMuted)
                            )
                        }
                    } ?: Spacer(Modifier.width(1.dp))
                }
            }

            Text(
                "LIVE TRIVIA",
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = sideSlotWidth),
                style = TextStyle(
                    fontSize = 15.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp,
                    color = Amber
                ),
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        // Main content
        Box(modifier = Modifier.weight(1f)) {
            AppBackground()
            when {
                showJoinWait -> JoinWaitView(targetMs = joinWaitTargetMs)
                liveState != null && liveViewModel.isLocallyInQuiz && localPhase == Phase.QUESTION ->
                    QuestionView(
                        liveViewModel = liveViewModel,
                        localQuestionIndex = localQuestionIndex,
                        localSecondsRemaining = localSecondsRemaining,
                        eliminatedIndices = eliminatedIndices
                    )
                liveState != null && liveViewModel.isLocallyInQuiz && localPhase == Phase.EXPLANATION ->
                    ExplanationView(
                        liveViewModel = liveViewModel,
                        localQuestionIndex = localQuestionIndex,
                        localSecondsRemaining = localSecondsRemaining
                    )
                liveState != null && localPhase == Phase.RESULTS ->
                    ResultsView(userSession = userSession, liveState = liveState)
                liveState != null ->
                    LeaderboardScreen(roundId = liveState?.roundId)
                error != null ->
                    ErrorView(error = error!!, onRetry = { liveViewModel.startSync() })
                else ->
                    LoadingView()
            }
        }

        // Timer bar (only during quiz)
        if (liveState != null && liveViewModel.isLocallyInQuiz && !showJoinWait) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppSurface)
                    .padding(horizontal = 20.dp, vertical = 8.dp)
            ) {
                if (localPhase == Phase.QUESTION) {
                    val session = userSession
                    val pts = if (session != null && session.hasAnswered(localQuestionIndex)) {
                        val ans = session.getAnswer(localQuestionIndex)
                        Scoring.points(LiveTriviaState.QUESTION_TIME, ans?.timeRemaining ?: 0.0, true)
                    } else {
                        Scoring.points(LiveTriviaState.QUESTION_TIME, localSecondsRemaining, true)
                    }
                    Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                        Text(
                            "$pts",
                            style = TextStyle(
                                fontSize = 20.sp,
                                fontFamily = FontFamily.Serif,
                                fontWeight = FontWeight.Bold,
                                color = Amber
                            )
                        )
                        Spacer(Modifier.width(4.dp))
                        Text(
                            "pts available",
                            style = TextStyle(fontSize = 14.sp, color = TextMuted)
                        )
                    }
                    Spacer(Modifier.height(4.dp))
                }
                val total = if (localPhase == Phase.QUESTION) LiveTriviaState.QUESTION_TIME else LiveTriviaState.EXPLANATION_TIME
                LiveTimerBar(fraction = (localSecondsRemaining / total).toFloat())
            }
        }

        BannerAdView(modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun JoinWaitView(targetMs: Long) {
    var nowMs by remember(targetMs) { mutableStateOf(System.currentTimeMillis()) }

    LaunchedEffect(targetMs) {
        while (isActive) {
            nowMs = System.currentTimeMillis()
            if (nowMs >= targetMs) break
            delay(250L)
        }
    }

    val remaining = maxOf(0L, targetMs - nowMs)
    val displaySecs = ((remaining + 999L) / 1000L).toInt()
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "FIRST QUESTION IN",
                style = TextStyle(
                    fontSize = 13.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp,
                    color = TextMuted
                )
            )
            Spacer(Modifier.height(16.dp))
            Text(
                "$displaySecs",
                style = TextStyle(
                    fontSize = 96.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = Amber
                )
            )
        }
    }
}

@Composable
private fun QuestionView(
    liveViewModel: LiveTriviaViewModel,
    localQuestionIndex: Int,
    localSecondsRemaining: Double,
    eliminatedIndices: Set<Int>
) {
    val question = liveViewModel.getCurrentQuestion()
    val userSession by liveViewModel.userSession.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(top = 20.dp, bottom = 16.dp)
    ) {
        question?.let { q ->
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                CategoryPill(name = q.category.uppercase())
            }
            Spacer(Modifier.height(12.dp))

            AppCard(modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth()) {
                Text(
                    q.question,
                    modifier = Modifier.padding(20.dp).fillMaxWidth(),
                    style = TextStyle(
                        fontSize = 17.sp,
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary,
                        textAlign = TextAlign.Center
                    )
                )
            }
            Spacer(Modifier.height(12.dp))

            val letters = listOf("A", "B", "C", "D")
            q.choices.forEachIndexed { index, choice ->
                val isSelected = userSession?.getAnswer(localQuestionIndex)?.selectedIndex == index
                val isEliminated = eliminatedIndices.contains(index)
                AnswerButton(
                    text = choice,
                    letter = letters[index],
                    isSelected = isSelected,
                    isEliminated = isEliminated,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 5.dp)
                ) {
                    if (!isEliminated) {
                        liveViewModel.recordAnswer(index, localSecondsRemaining)
                    }
                }
            }
        } ?: run {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Loading question...", style = TextStyle(color = TextMuted, fontSize = 14.sp))
            }
        }
    }
}

@Composable
private fun AnswerButton(
    text: String,
    letter: String,
    isSelected: Boolean,
    isEliminated: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isSelected) Amber.copy(alpha = 0.1f) else com.copanostudios.marylanddailytrivia.ui.theme.CardBg,
            disabledContainerColor = com.copanostudios.marylanddailytrivia.ui.theme.CardBg.copy(alpha = 0.4f)
        ),
        enabled = !isEliminated,
        border = androidx.compose.foundation.BorderStroke(
            width = if (isSelected) 2.dp else 1.dp,
            color = when {
                isEliminated -> Color.Transparent
                isSelected -> Amber
                else -> CardBorder
            }
        )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .background(
                        color = when {
                            isEliminated -> Amber.copy(alpha = 0.1f)
                            isSelected -> Amber
                            else -> Amber.copy(alpha = 0.15f)
                        },
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = when {
                        isEliminated -> "✗"
                        isSelected -> "✓"
                        else -> letter
                    },
                    style = TextStyle(
                        fontSize = 13.sp,
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        color = when {
                            isEliminated -> Color.White.copy(alpha = 0.4f)
                            isSelected -> Color.White
                            else -> Amber
                        }
                    )
                )
            }
            Spacer(Modifier.width(12.dp))
            Text(
                text = text,
                style = TextStyle(
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isEliminated) TextPrimary.copy(alpha = 0.4f) else TextPrimary,
                    textDecoration = if (isEliminated) TextDecoration.LineThrough else TextDecoration.None
                )
            )
        }
    }
}

@Composable
private fun ExplanationView(
    liveViewModel: LiveTriviaViewModel,
    localQuestionIndex: Int,
    localSecondsRemaining: Double
) {
    val question = liveViewModel.getCurrentQuestion()
    val userSession by liveViewModel.userSession.collectAsState()
    val userAnswer = userSession?.getAnswer(localQuestionIndex)

    val explanationSecs = maxOf(0.0, minOf(LiveTriviaState.EXPLANATION_TIME, localSecondsRemaining))
    val explanationFraction = (explanationSecs / LiveTriviaState.EXPLANATION_TIME).toFloat().coerceIn(0f, 1f)
    val countdownColor = when {
        explanationSecs <= 3.0 -> Error
        explanationSecs <= 6.0 -> Warning
        else -> Amber
    }
    val labelText = if (localQuestionIndex < 9) "NEXT QUESTION IN" else "ROUND RESULTS IN"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(20.dp))
        if (userAnswer != null) {
            Text(
                if (userAnswer.isCorrect) "✓" else "✗",
                style = TextStyle(
                    fontSize = 56.sp,
                    color = if (userAnswer.isCorrect) Success else Error
                )
            )
            Text(
                if (userAnswer.isCorrect) "Correct!" else "Incorrect",
                style = TextStyle(
                    fontSize = 24.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
            if (userAnswer.pointsEarned > 0) {
                Text(
                    "+${userAnswer.pointsEarned} points",
                    style = TextStyle(
                        fontSize = 20.sp,
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        color = Amber
                    )
                )
            }
        } else {
            Text("⏰", style = TextStyle(fontSize = 56.sp))
            Text(
                "Time's Up!",
                style = TextStyle(
                    fontSize = 24.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
        }

        Spacer(Modifier.height(20.dp))
        question?.let { q ->
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp).fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "CORRECT ANSWER",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.sp,
                            color = TextMuted
                        )
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        q.choices[q.correctIndex],
                        style = TextStyle(
                            fontSize = 16.sp,
                            fontFamily = FontFamily.Serif,
                            fontWeight = FontWeight.SemiBold,
                            color = Success,
                            textAlign = TextAlign.Center
                        )
                    )
                }
            }
            q.explanation?.takeIf { it.isNotEmpty() }?.let { exp ->
                Spacer(Modifier.height(16.dp))
                Text(
                    exp,
                    style = TextStyle(
                        fontSize = 14.sp,
                        color = TextSecondary,
                        textAlign = TextAlign.Center
                    )
                )
            }
        }

        // "Next Question In" countdown card
        Spacer(Modifier.height(20.dp))
        AppCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(14.dp).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    labelText,
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.4.sp,
                        color = TextMuted
                    )
                )
                Spacer(Modifier.height(10.dp))
                Box(
                    modifier = Modifier.size(64.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(
                        progress = { 1f },
                        modifier = Modifier.size(64.dp),
                        color = CardBorder.copy(alpha = 0.5f),
                        strokeWidth = 4.dp
                    )
                    CircularProgressIndicator(
                        progress = { explanationFraction },
                        modifier = Modifier.size(64.dp),
                        color = countdownColor,
                        strokeWidth = 4.dp,
                        strokeCap = androidx.compose.ui.graphics.StrokeCap.Round
                    )
                    Text(
                        "${kotlin.math.ceil(explanationSecs).toInt()}",
                        style = TextStyle(
                            fontSize = 20.sp,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Black,
                            color = countdownColor
                        )
                    )
                }
            }
        }
    }
}

@Composable
private fun ResultsView(userSession: com.copanostudios.marylanddailytrivia.data.UserAnswerSession?, liveState: LiveTriviaState?) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(24.dp)) {
            ArmadilloLogo(width = 220.dp)
            Spacer(Modifier.height(8.dp))
            NeonText("ROUND COMPLETE", size = 20.sp)
            Spacer(Modifier.height(16.dp))
            Text(
                "${userSession?.totalScore ?: 0}",
                style = TextStyle(
                    fontSize = 52.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Black,
                    color = Amber
                )
            )
            Text(
                "POINTS",
                style = TextStyle(
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp,
                    color = TextMuted
                )
            )
            Spacer(Modifier.height(16.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(30.dp),
                modifier = Modifier
                    .background(com.copanostudios.marylanddailytrivia.ui.theme.CardBg, RoundedCornerShape(14.dp))
                    .border(1.dp, CardBorder, RoundedCornerShape(14.dp))
                    .padding(16.dp)
            ) {
                StatItem("${userSession?.questionsAnswered ?: 0}", "Answered", TextPrimary)
                StatItem("${userSession?.correctCount ?: 0}", "Correct", Success)
            }
            liveState?.let {
                Spacer(Modifier.height(12.dp))
                Text(
                    "Leaderboard in ${it.secondsRemaining}s...",
                    style = TextStyle(fontSize = 13.sp, color = TextMuted)
                )
            }
        }
    }
}

@Composable
private fun StatItem(value: String, label: String, valueColor: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            value,
            style = TextStyle(
                fontSize = 22.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                color = valueColor
            )
        )
        Text(label, style = TextStyle(fontSize = 11.sp, color = TextMuted))
    }
}

@Composable
private fun LoadingView() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = Amber)
            Spacer(Modifier.height(16.dp))
            Text(
                "Connecting to live trivia...",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )
            )
        }
    }
}

@Composable
private fun ErrorView(error: Throwable, onRetry: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(32.dp)
        ) {
            Text("⚠", style = TextStyle(fontSize = 44.sp, color = Error.copy(alpha = 0.7f)))
            Spacer(Modifier.height(12.dp))
            Text(
                "Connection Error",
                style = TextStyle(
                    fontSize = 18.sp,
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            )
            Text(
                error.message ?: "Unknown error",
                style = TextStyle(
                    fontSize = 13.sp,
                    color = TextMuted,
                    textAlign = TextAlign.Center
                )
            )
            Spacer(Modifier.height(16.dp))
            GlowingButton("Retry", onClick = onRetry, modifier = Modifier.padding(horizontal = 60.dp))
        }
    }
}
