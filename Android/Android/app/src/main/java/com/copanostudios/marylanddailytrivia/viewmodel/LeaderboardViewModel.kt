package com.copanostudios.marylanddailytrivia.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.copanostudios.marylanddailytrivia.AppContainer
import com.copanostudios.marylanddailytrivia.data.DailyLeaderboardResponse
import com.copanostudios.marylanddailytrivia.data.LeaderboardResponse
import com.copanostudios.marylanddailytrivia.data.RateLimitedException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class LeaderboardViewModel : ViewModel() {

    private val repository = AppContainer.repository
    val currentUserId: String = AppContainer.storage.getOrCreateUserId()

    private val _leaderboard = MutableStateFlow<LeaderboardResponse?>(null)
    val leaderboard: StateFlow<LeaderboardResponse?> = _leaderboard.asStateFlow()

    private val _dailyLeaderboard = MutableStateFlow<DailyLeaderboardResponse?>(null)
    val dailyLeaderboard: StateFlow<DailyLeaderboardResponse?> = _dailyLeaderboard.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<Throwable?>(null)
    val error: StateFlow<Throwable?> = _error.asStateFlow()

    private val _retryCooldownSeconds = MutableStateFlow(0)
    val retryCooldownSeconds: StateFlow<Int> = _retryCooldownSeconds.asStateFlow()

    private var refreshJob: Job? = null
    private var cooldownJob: Job? = null
    private var autoRetryJob: Job? = null
    private var lastRoundId: String? = null

    fun loadLeaderboard(roundId: String?) {
        lastRoundId = roundId
        viewModelScope.launch { fetchLeaderboard(roundId) }
        startAutoRefresh(roundId)
    }

    fun retryLoad() {
        if (_retryCooldownSeconds.value > 0) return
        viewModelScope.launch { fetchLeaderboard(lastRoundId) }
    }

    private suspend fun fetchLeaderboard(roundId: String?) {
        if (_retryCooldownSeconds.value > 0) return
        _isLoading.value = true
        _error.value = null
        try {
            if (roundId != null) {
                _leaderboard.value = repository.getLeaderboard(roundId)
            } else {
                _dailyLeaderboard.value = repository.getDailyLeaderboard()
            }
            clearCooldown()
        } catch (e: RateLimitedException) {
            _error.value = e
            startCooldown(e.retryAfterSeconds, roundId)
        } catch (e: Exception) {
            _error.value = e
        }
        _isLoading.value = false
    }

    private fun startCooldown(seconds: Int, roundId: String?) {
        val secs = maxOf(1, seconds)
        _retryCooldownSeconds.value = secs
        cooldownJob?.cancel()
        cooldownJob = viewModelScope.launch {
            repeat(secs) {
                delay(1_000L)
                if (_retryCooldownSeconds.value > 0) _retryCooldownSeconds.value -= 1
            }
        }
        autoRetryJob?.cancel()
        autoRetryJob = viewModelScope.launch {
            delay(secs * 1_000L)
            fetchLeaderboard(roundId)
        }
    }

    private fun clearCooldown() {
        _retryCooldownSeconds.value = 0
        cooldownJob?.cancel()
        autoRetryJob?.cancel()
    }

    private fun startAutoRefresh(roundId: String?) {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            while (isActive) {
                delay(30_000L)
                fetchLeaderboard(roundId)
            }
        }
    }

    fun stopRefresh() {
        refreshJob?.cancel()
    }

    override fun onCleared() {
        super.onCleared()
        refreshJob?.cancel()
        cooldownJob?.cancel()
        autoRetryJob?.cancel()
    }
}
