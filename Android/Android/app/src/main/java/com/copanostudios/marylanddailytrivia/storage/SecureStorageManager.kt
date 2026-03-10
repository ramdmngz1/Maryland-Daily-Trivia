package com.copanostudios.marylanddailytrivia.storage

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.util.UUID

/**
 * Encrypted storage equivalent to iOS KeychainHelper.
 * Uses EncryptedSharedPreferences (AES256_SIV key, AES256_GCM value).
 */
class SecureStorageManager(context: Context) {

    // Non-sensitive app preferences (haptics, motion, rules acknowledgement)
    private val appPrefs: SharedPreferences =
        context.getSharedPreferences("texas_trivia_app_prefs", Context.MODE_PRIVATE)

    private val prefs by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "texas_trivia_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun save(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    fun read(key: String): String? = prefs.getString(key, null)

    fun delete(key: String) {
        prefs.edit().remove(key).apply()
    }

    /** Get or create persistent device user ID. */
    fun getOrCreateUserId(): String {
        val key = "contest_user_id"
        return read(key) ?: run {
            val newId = "device_${UUID.randomUUID()}"
            // commit() instead of apply() — guarantees the ID is persisted before
            // the process can be killed, preventing a new UUID being generated on
            // the next launch (which would create a duplicate leaderboard identity).
            prefs.edit().putString(key, newId).commit()
            newId
        }
    }

    /** Get username, returns empty string if not set. */
    fun getOrCreateUsername(): String = read("contest_username") ?: ""

    /** Save username. */
    fun saveUsername(username: String) {
        save("contest_username", username)
    }

    // MARK: - App Preferences (non-sensitive)

    fun getHapticsEnabled(): Boolean = appPrefs.getBoolean("pref_haptics_enabled", true)
    fun setHapticsEnabled(enabled: Boolean) {
        appPrefs.edit().putBoolean("pref_haptics_enabled", enabled).apply()
    }

    fun getReduceMotionEnabled(): Boolean = appPrefs.getBoolean("pref_reduce_motion", false)
    fun setReduceMotionEnabled(enabled: Boolean) {
        appPrefs.edit().putBoolean("pref_reduce_motion", enabled).apply()
    }

    fun getHasAcknowledgedRules(): Boolean = appPrefs.getBoolean("has_acknowledged_rules_v1", false)
    fun setHasAcknowledgedRules(acknowledged: Boolean) {
        appPrefs.edit().putBoolean("has_acknowledged_rules_v1", acknowledged).apply()
    }

    fun getHasPendingRules(): Boolean = appPrefs.getBoolean("pending_rules_acknowledgement_v1", false)
    fun setHasPendingRules(pending: Boolean) {
        appPrefs.edit().putBoolean("pending_rules_acknowledgement_v1", pending).apply()
    }

}
