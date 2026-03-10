package com.copanostudios.marylanddailytrivia.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class TriviaDifficulty {
    @SerialName("easy") EASY,
    @SerialName("medium") MEDIUM,
    @SerialName("hard") HARD
}

@Serializable
data class TriviaQuestion(
    val id: String,
    val category: String,
    val difficulty: TriviaDifficulty,
    val question: String,
    val choices: List<String>,
    val correctIndex: Int,
    val explanation: String? = null,
    val source: String? = null,
    val tags: List<String>? = null
) {
    val isValid: Boolean
        get() = choices.size == 4 &&
                correctIndex in 0 until choices.size &&
                question.isNotBlank()
}
