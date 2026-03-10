package com.copanostudios.marylanddailytrivia.data

data class TriviaRule(
    val id: String,
    val icon: String,       // Unicode emoji icon
    val title: String,
    val detail: String
)

object TriviaRules {
    val items: List<TriviaRule> = listOf(
        TriviaRule(
            id = "questions-per-round",
            icon = "❓",
            title = "10 Questions Per Round",
            detail = "All players get the same questions at the same time. A new round starts every ~4 minutes."
        ),
        TriviaRule(
            id = "seconds-per-question",
            icon = "⏱",
            title = "12 Seconds Per Question",
            detail = "Answer fast! You earn bonus points based on how quickly you respond."
        ),
        TriviaRule(
            id = "scoring",
            icon = "⭐",
            title = "Scoring",
            detail = "Every question is worth up to 1,000 pts. Points decrease as the timer runs down. Answer fast for maximum points! Wrong answers score 0."
        ),
        TriviaRule(
            id = "leaderboard",
            icon = "🏆",
            title = "Leaderboard",
            detail = "Your scores are totaled for the day. The leaderboard resets every 24 hours. Ties are broken by speed."
        ),
        TriviaRule(
            id = "play-anytime",
            icon = "⚡",
            title = "Play Anytime",
            detail = "Rounds run continuously 24/7. Jump in whenever you want and compete against other players live."
        )
    )
}
