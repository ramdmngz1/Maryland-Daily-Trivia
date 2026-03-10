package com.copanostudios.marylanddailytrivia

import android.content.Context
import com.copanostudios.marylanddailytrivia.core.AuthManager
import com.copanostudios.marylanddailytrivia.network.ContestRepository
import com.copanostudios.marylanddailytrivia.network.SecureHttpClient
import com.copanostudios.marylanddailytrivia.storage.SecureStorageManager

/**
 * Service locator — initialised once in MainActivity.onCreate().
 * Provides singleton instances to ViewModels without a DI framework.
 */
object AppContainer {

    private lateinit var appContext: Context

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    val storage: SecureStorageManager by lazy { SecureStorageManager(appContext) }

    val authManager: AuthManager by lazy {
        AuthManager(storage, SecureHttpClient.okHttpClient)
    }

    val repository: ContestRepository by lazy {
        ContestRepository.create(authManager)
    }
}
