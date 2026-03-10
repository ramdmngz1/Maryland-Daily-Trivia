package com.copanostudios.marylanddailytrivia.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.copanostudios.marylanddailytrivia.AppContainer
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class HomeViewModel : ViewModel() {

    private val repository = AppContainer.repository
    private val storage = AppContainer.storage

    private val _activePlayerCount = MutableStateFlow(0)
    val activePlayerCount: StateFlow<Int> = _activePlayerCount.asStateFlow()

    private val _username = MutableStateFlow(storage.getOrCreateUsername())
    val username: StateFlow<String> = _username.asStateFlow()

    private var pollJob: Job? = null

    init {
        startPolling()
    }

    fun refreshUsername() {
        _username.value = storage.getOrCreateUsername()
    }

    private fun startPolling() {
        pollJob?.cancel()
        pollJob = viewModelScope.launch {
            while (isActive) {
                fetchPlayerCount()
                delay(20_000L)
            }
        }
    }

    private suspend fun fetchPlayerCount() {
        try {
            val state = repository.getLiveState()
            _activePlayerCount.value = state.activePlayerCount
        } catch (_: Exception) {
            // Non-critical
        }
    }

    override fun onCleared() {
        super.onCleared()
        pollJob?.cancel()
    }
}
