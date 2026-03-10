package com.copanostudios.marylanddailytrivia.core

import com.copanostudios.marylanddailytrivia.data.TriviaQuestion

/**
 * Deterministic answer-position balancer.
 * CRITICAL: Must produce identical shuffles to iOS for the same seed.
 * Uses SplitMix64 RNG + exact replication of Swift's Fisher-Yates shuffle algorithm.
 */
object AnswerPositionBalancer  {

    /**
     * Shuffles answer choices per question and balances correct-answer positions (A/B/C/D)
     * across the question set.
     *
     * @param questions List of questions to shuffle
     * @param seed ULong seed = (roundStartTime ms / 1000).toULong() (epoch seconds)
     */
    fun balancedShuffled(questions: List<TriviaQuestion>, seed: ULong): List<TriviaQuestion> {
        val gen = SeededGenerator(seed)
        val slotCounts = IntArray(4)

        return questions.map { q ->
            if (q.choices.size != 4 || q.correctIndex !in 0..3) return@map q

            val correctAnswer = q.choices[q.correctIndex]
            var bestQuestion: TriviaQuestion? = null
            var bestScore = Int.MAX_VALUE

            // Try 12 shuffles and pick the one that best balances slot usage
            repeat(12) {
                val choices = q.choices.toMutableList()
                choices.shuffleWith(gen)

                val newCorrectIndex = choices.indexOf(correctAnswer)
                if (newCorrectIndex == -1) return@repeat

                val score = slotCounts[newCorrectIndex]
                if (score < bestScore) {
                    bestScore = score
                    bestQuestion = q.copy(choices = choices, correctIndex = newCorrectIndex)
                }
            }

            val final = bestQuestion ?: q
            slotCounts[final.correctIndex]++
            final
        }
    }

    /**
     * Fisher-Yates shuffle using SeededGenerator.
     * Exactly replicates Swift Collection.shuffle(using:) algorithm.
     */
    private fun <T> MutableList<T>.shuffleWith(gen: SeededGenerator) {
        val n = size
        for (i in 0 until n - 1) {
            val remaining = (n - i).toULong()
            // Unbiased bounded random in [0, remaining): threshold = (2^64 % remaining)
            // = (ULong.MAX_VALUE % remaining + 1) % remaining
            val threshold = (ULong.MAX_VALUE % remaining + 1uL) % remaining
            var r: ULong
            do { r = gen.next() } while (r < threshold)
            val j = i + (r % remaining).toInt()
            // Swap i and j
            val tmp = this[i]; this[i] = this[j]; this[j] = tmp
        }
    }
}

/**
 * SplitMix64 deterministic RNG.
 * Bit-for-bit identical to iOS SeededGenerator.
 */
class SeededGenerator(seed: ULong) {
    private var state: ULong = if (seed == 0uL) 0xDEADBEEFuL else seed

    fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }
}
