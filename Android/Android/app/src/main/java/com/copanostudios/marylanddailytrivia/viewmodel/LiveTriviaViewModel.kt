package com.copanostudios.marylanddailytrivia.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.copanostudios.marylanddailytrivia.AppContainer
import com.copanostudios.marylanddailytrivia.BuildConfig
import com.copanostudios.marylanddailytrivia.core.AnswerElimination
import com.copanostudios.marylanddailytrivia.core.AnswerPositionBalancer
import com.copanostudios.marylanddailytrivia.core.EliminationState
import com.copanostudios.marylanddailytrivia.core.Scoring
import com.copanostudios.marylanddailytrivia.data.AnswerSubmission
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
    private val localTickIntervalMs = 100L
    private var currentSyncIntervalMs: Long = 1_000L
    private var cachedBalancedRoundId: String? = null

    private fun phaseBasedInterval(): Long = when (_localPhase.value) {
        Phase.QUESTION -> 1_000L
        Phase.EXPLANATION -> 2_000L
        else -> 3_000L
    }

    private var eliminationState = EliminationState()

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
                delay(localTickIntervalMs)
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
        val (phase, qIndex, exactRemaining) = state.localState()
        if (phase != Phase.QUESTION) return

        val question = _currentQuestions.value.getOrNull(qIndex) ?: return
        if (_eliminatedIndices.value.contains(selectedIndex)) return

        val session = _userSession.value ?: UserAnswerSession(state.roundId)
        val answerTimeRemaining = exactRemaining.coerceIn(0.0, LiveTriviaState.QUESTION_TIME)

        // Ignore re-selecting same answer
        if (session.getAnswer(qIndex)?.selectedIndex == selectedIndex) return

        val isCorrect = selectedIndex == question.correctIndex
        val pts = Scoring.points(
            timeLimit = LiveTriviaState.QUESTION_TIME,
            secondsRemaining = answerTimeRemaining,
            isCorrect = isCorrect
        )

        _userSession.value = session.recordAnswer(
            questionIndex = qIndex,
            questionId = question.id,
            selectedIndex = selectedIndex,
            isCorrect = isCorrect,
            pointsEarned = pts,
            timeRemaining = answerTimeRemaining
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
        if (cachedBalancedRoundId == state.roundId &&
            _currentQuestions.value.size >= state.questionIds.size
        ) return
        try {
            val questions = repository.getQuestions(state.questionIds)
            _currentQuestions.value = AnswerPositionBalancer.balancedShuffled(
                questions,
                seed = state.roundSeedULong
            )
            if (questions.size >= state.questionIds.size) {
                cachedBalancedRoundId = state.roundId
            }
        } catch (e: Exception) {
            _error.value = e
        }
    }

    private fun handleRoundChange(newState: LiveTriviaState) {
        _userSession.value = UserAnswerSession(newState.roundId)
        scoreSubmitted = false
        eliminationState = EliminationState()
        _eliminatedIndices.value = emptySet()
    }

    private fun updateLocalState() {
        val state = _liveState.value ?: return
        val (phase, qIndex, remaining) = state.localState(System.currentTimeMillis())

        val prevPhase = _localPhase.value
        val prevIndex = _localQuestionIndex.value

        if (_localPhase.value != phase) {
            _localPhase.value = phase
        }
        if (_localQuestionIndex.value != qIndex) {
            _localQuestionIndex.value = qIndex
        }
        if (kotlin.math.abs(_localSecondsRemaining.value - remaining) >= localTickIntervalMs / 1000.0 || remaining <= 0.0) {
            _localSecondsRemaining.value = remaining
        }

        // Submit score when transitioning into RESULTS phase (once per round)
        if (prevPhase != Phase.RESULTS && phase == Phase.RESULTS && !scoreSubmitted) {
            scoreSubmitted = true
            viewModelScope.launch { submitScore() }
        }

        if (phase == Phase.QUESTION) {
            val question = getCurrentQuestion()
            if (question != null) {
                val currentSelection = _userSession.value?.getAnswer(qIndex)?.selectedIndex
                val result = AnswerElimination.update(
                    eliminationState, qIndex, remaining,
                    question.correctIndex, question.choices.size, currentSelection,
                )
                eliminationState = result.state
                _eliminatedIndices.value = result.state.eliminated
                if (result.shouldClearSelection) {
                    _userSession.value = _userSession.value?.clearAnswer(qIndex)
                }
            }
        } else if (phase != Phase.QUESTION && prevPhase == Phase.QUESTION) {
            eliminationState = EliminationState()
            _eliminatedIndices.value = emptySet()
        }
    }

    private suspend fun submitScore() {
        val session = _userSession.value ?: return
        val state = _liveState.value ?: return
        if (session.questionsAnswered == 0) return

        val userId = storage.getOrCreateUserId()
        val username = storage.getOrCreateUsername().ifEmpty { "Anonymous" }
        val completionTime = session.questionsAnswered * LiveTriviaState.QUESTION_CYCLE
        val answers = session.answers
            .toSortedMap()
            .values
            .map { answer ->
                AnswerSubmission(
                    questionId = answer.questionId,
                    selectedIndex = answer.selectedIndex,
                    timeRemaining = answer.timeRemaining,
                    isCorrect = answer.isCorrect
                )
            }

        val submission = ScoreSubmission(
            userId = userId,
            username = username,
            score = session.totalScore,
            completionTime = completionTime,
            answers = answers
        )
        for (attempt in 0 until 3) {
            try {
                repository.submitScore(state.roundId, submission)
                return
            } catch (e: Exception) {
                if (BuildConfig.DEBUG) {
                    android.util.Log.w("LiveTrivia", "Score submission attempt ${attempt + 1} failed", e)
                }
                if (attempt < 2) delay(((attempt + 1) * 1000).toLong())
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopSync()
    }
}
