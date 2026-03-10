package com.copanostudios.marylanddailytrivia.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.copanostudios.marylanddailytrivia.AppContainer
import com.copanostudios.marylanddailytrivia.core.AnswerPositionBalancer
import com.copanostudios.marylanddailytrivia.core.Scoring
import com.copanostudios.marylanddailytrivia.data.LiveTriviaState
import com.copanostudios.marylanddailytrivia.data.Phase
import com.copanostudios.marylanddailytrivia.data.ScoreSubmission
import com.copanostudios.marylanddailytrivia.data.TriviaQuestion
import com.copanostudios.marylanddailytrivia.data.UserAnswerSession
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import retrofit2.HttpException
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class LiveTriviaViewModel : ViewModel() {

    private val repository = AppContainer.repository
    private val storage = AppContainer.storage

    // MARK: — StateFlows

    private val _liveState = MutableStateFlow<LiveTriviaState?>(null)
    val liveState: StateFlow<LiveTriviaState?> = _liveState.asStateFlow()

    private val _currentQuestions = MutableStateFlow<List<TriviaQuestion>>(emptyList())
    val currentQuestions: StateFlow<List<TriviaQuestion>> = _currentQuestions.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<Throwable?>(null)
    val error: StateFlow<Throwable?> = _error.asStateFlow()

    private val _userSession = MutableStateFlow<UserAnswerSession?>(null)
    val userSession: StateFlow<UserAnswerSession?> = _userSession.asStateFlow()

    private val _localPhase = MutableStateFlow(Phase.QUESTION)
    val localPhase: StateFlow<Phase> = _localPhase.asStateFlow()

    private val _localQuestionIndex = MutableStateFlow(0)
    val localQuestionIndex: StateFlow<Int> = _localQuestionIndex.asStateFlow()

    private val _localSecondsRemaining = MutableStateFlow(12.0)
    val localSecondsRemaining: StateFlow<Double> = _localSecondsRemaining.asStateFlow()

    private val _eliminatedIndices = MutableStateFlow<Set<Int>>(emptySet())
    val eliminatedIndices: StateFlow<Set<Int>> = _eliminatedIndices.asStateFlow()

    // MARK: — Private state

    private var pollingJob: Job? = null
    private var tickJob: Job? = null
    private var currentSyncIntervalMs: Long = 1_000L
    private var cachedBalancedRoundId: String? = null

    private fun phaseBasedInterval(): Long = when (_localPhase.value) {
        Phase.QUESTION -> 1_000L
        Phase.EXPLANATION -> 2_000L
        else -> 3_000L
    }

    private var eliminationQuestionIndex = -1
    private var hasEliminatedFirst = false
    private var hasEliminatedSecond = false

    private var scoreSubmitted = false

    // MARK: — Public API

    val isLocallyInQuiz: Boolean
        get() = _localQuestionIndex.value in 0 until 10 &&
                (_localPhase.value == Phase.QUESTION || _localPhase.value == Phase.EXPLANATION)

    fun getCurrentQuestion(): TriviaQuestion? {
        val idx = _localQuestionIndex.value
        val questions = _currentQuestions.value
        return if (idx in questions.indices) questions[idx] else null
    }

    fun hasAnsweredCurrent(): Boolean =
        _userSession.value?.hasAnswered(_localQuestionIndex.value) == true

    fun startSync() {
        if (pollingJob?.isActive == true) return

        pollingJob = viewModelScope.launch {
            while (isActive) {
                fetchLiveState()
                delay(currentSyncIntervalMs)
            }
        }

        tickJob = viewModelScope.launch {
            while (isActive) {
                delay(50)
                updateLocalState()
            }
        }
    }

    fun stopSync() {
        pollingJob?.cancel()
        tickJob?.cancel()
        pollingJob = null
        tickJob = null
    }

    fun recordAnswer(selectedIndex: Int, timeRemaining: Double) {
        val state = _liveState.value ?: return
        if (!isLocallyInQuiz || _localPhase.value != Phase.QUESTION) return
        val question = getCurrentQuestion() ?: return
        if (_eliminatedIndices.value.contains(selectedIndex)) return

        val session = _userSession.value ?: UserAnswerSession(state.roundId)
        val qIndex = _localQuestionIndex.value

        // Ignore re-selecting same answer
        if (session.getAnswer(qIndex)?.selectedIndex == selectedIndex) return

        val isCorrect = selectedIndex == question.correctIndex
        val pts = Scoring.points(
            timeLimit = LiveTriviaState.QUESTION_TIME,
            secondsRemaining = timeRemaining,
            isCorrect = isCorrect
        )

        _userSession.value = session.recordAnswer(
            questionIndex = qIndex,
            questionId = question.id,
            selectedIndex = selectedIndex,
            isCorrect = isCorrect,
            pointsEarned = pts,
            timeRemaining = timeRemaining
        )
    }

    // MARK: — Private methods

    private suspend fun fetchLiveState() {
        try {
            val newState = repository.getLiveState()
            val roundChanged = _liveState.value?.roundId != newState.roundId

            _liveState.value = newState
            _error.value = null

            if (roundChanged) handleRoundChange(newState)

            if (_currentQuestions.value.isEmpty() || roundChanged) {
                loadQuestions(newState)
            }

            // Phase-based polling cadence on success
            currentSyncIntervalMs = phaseBasedInterval()
        } catch (e: HttpException) {
            if (e.code() == 429) {
                // Respect Retry-After, don't surface 429 as an error to the UI
                val retryAfter = e.response()?.headers()?.get("Retry-After")?.toLongOrNull() ?: 5L
                currentSyncIntervalMs = maxOf(retryAfter * 1_000L, 5_000L)
                return
            }
            _error.value = e
            currentSyncIntervalMs = minOf(currentSyncIntervalMs * 2, 30_000L)
        } catch (e: Exception) {
            _error.value = e
            currentSyncIntervalMs = minOf(currentSyncIntervalMs * 2, 30_000L)
        }
    }

    private suspend fun loadQuestions(state: LiveTriviaState) {
        if (cachedBalancedRoundId == state.roundId && _currentQuestions.value.isNotEmpty()) return
        try {
            val questions = repository.getQuestions(state.questionIds)
            _currentQuestions.value = AnswerPositionBalancer.balancedShuffled(
                questions,
                seed = state.roundSeedULong
            )
            cachedBalancedRoundId = state.roundId
        } catch (e: Exception) {
            _error.value = e
        }
    }

    private fun handleRoundChange(newState: LiveTriviaState) {
        _userSession.value = UserAnswerSession(newState.roundId)
        scoreSubmitted = false
        resetEliminations()
    }

    private fun updateLocalState() {
        val state = _liveState.value ?: return
        val (phase, qIndex, remaining) = state.localState(System.currentTimeMillis())

        val prevPhase = _localPhase.value
        val prevIndex = _localQuestionIndex.value

        _localPhase.value = phase
        _localQuestionIndex.value = qIndex
        _localSecondsRemaining.value = remaining

        // Submit score when transitioning into RESULTS phase (once per round)
        if (prevPhase != Phase.RESULTS && phase == Phase.RESULTS && !scoreSubmitted) {
            scoreSubmitted = true
            viewModelScope.launch { submitScore() }
        }

        // Reset eliminations on question change
        if (phase == Phase.QUESTION && qIndex != prevIndex) {
            resetEliminations()
        }

        if (phase == Phase.QUESTION) {
            updateEliminationsLocally(qIndex, remaining)
        }
    }

    private suspend fun submitScore() {
        val session = _userSession.value ?: return
        val state = _liveState.value ?: return
        if (session.questionsAnswered == 0) return

        val userId = storage.getOrCreateUserId()
        val username = storage.getOrCreateUsername().ifEmpty { "Anonymous" }
        val completionTime = session.questionsAnswered * LiveTriviaState.QUESTION_CYCLE

        try {
            repository.submitScore(
                state.roundId,
                ScoreSubmission(
                    userId = userId,
                    username = username,
                    score = session.totalScore,
                    completionTime = completionTime
                )
            )
        } catch (_: Exception) {
            // Score submission failure is non-critical
        }
    }

    private fun updateEliminationsLocally(questionIndex: Int, remaining: Double) {
        if (questionIndex != eliminationQuestionIndex) {
            resetEliminations()
            eliminationQuestionIndex = questionIndex
        }
        if (remaining <= 8.0 && !hasEliminatedFirst) {
            hasEliminatedFirst = true
            eliminateOneWrongAnswer(questionIndex)
        }
        if (remaining <= 4.0 && !hasEliminatedSecond) {
            hasEliminatedSecond = true
            eliminateOneWrongAnswer(questionIndex)
        }
    }

    private fun eliminateOneWrongAnswer(questionIndex: Int) {
        val question = getCurrentQuestion() ?: return
        val currentSelection = _userSession.value?.getAnswer(questionIndex)?.selectedIndex
        val eliminated = _eliminatedIndices.value

        val candidates = (0 until question.choices.size).filter { idx ->
            idx != question.correctIndex && !eliminated.contains(idx)
        }
        val victim = candidates.randomOrNull() ?: return
        _eliminatedIndices.value = eliminated + victim

        // Clear the player's answer if it was eliminated
        if (currentSelection == victim) {
            _userSession.value = _userSession.value?.clearAnswer(questionIndex)
        }
    }

    private fun resetEliminations() {
        _eliminatedIndices.value = emptySet()
        hasEliminatedFirst = false
        hasEliminatedSecond = false
        eliminationQuestionIndex = -1
    }

    override fun onCleared() {
        super.onCleared()
        stopSync()
    }
}
