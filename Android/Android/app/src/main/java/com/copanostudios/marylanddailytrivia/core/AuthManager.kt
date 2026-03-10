package com.copanostudios.marylanddailytrivia.core

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.copanostudios.marylanddailytrivia.data.RefreshTokenResponse
import com.copanostudios.marylanddailytrivia.data.TokenResponse
import com.copanostudios.marylanddailytrivia.storage.SecureStorageManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.nio.charset.StandardCharsets
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

/**
 * Android auth manager.
 * Uses challenge-response attestation backed by Android Keystore.
 * Stores access/refresh tokens in EncryptedSharedPreferences.
 */
class AuthManager(
    private val storage: SecureStorageManager,
    private val okHttpClient: OkHttpClient
) {
    private val baseUrl = "https://maryland-trivia-contest.f22682jcz6.workers.dev"
    private val keyAlias = "texas_trivia_attest_key"

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val jsonMediaType = "application/json".toMediaType()

    private val accessTokenKey = "auth_access_token"
    private val refreshTokenKey = "auth_refresh_token"
    private val tokenExpiryKey = "auth_token_expiry"

    private val isAuthenticating = AtomicBoolean(false)

    /**
     * Ensures a valid access token exists.
     * If token valid → return immediately.
     * If refresh token exists → try refresh.
     * Otherwise → full Android Keystore attestation.
     */
    suspend fun ensureAuthenticated() {
        if (isAuthenticating.get()) return
        val expiry = getTokenExpiry()
        if (expiry != null && expiry > System.currentTimeMillis() + 60_000L &&
            storage.read(accessTokenKey) != null) {
            return
        }
        val refreshToken = storage.read(refreshTokenKey)
        if (refreshToken != null) {
            try {
                refreshAccessToken(refreshToken)
                return
            } catch (_: Exception) {
                // Fall through to full attestation
            }
        }
        performAttestation()
    }

    fun getAccessToken(): String? = storage.read(accessTokenKey)

    /** Clear tokens and re-authenticate. Call on 401. */
    suspend fun forceReauthenticate() {
        clearTokens()
        performAttestation()
    }

    private suspend fun performAttestation() {
        if (!isAuthenticating.compareAndSet(false, true)) return
        try {
            val deviceId = storage.getOrCreateUserId()
            repeat(8) { attempt ->
                val tokens = runCatching { attestOnce(deviceId) }.getOrNull()
                if (tokens != null) {
                    storeTokens(tokens)
                    return
                }
                delay(120L + (attempt * 30L))
            }
        } catch (_: Exception) {
            // Auth failed silently — will retry on next request
        } finally {
            isAuthenticating.set(false)
        }
    }

    private suspend fun attestOnce(deviceId: String): TokenResponse? {
        val challenge = fetchChallenge(deviceId)
        val keyPair = getOrCreateKeystoreKeyPair()
        val publicKeyBytes = keyPair.public.encoded
        val keyId = buildKeyId(publicKeyBytes)
        val signature = signChallenge(
            privateKey = keyPair.private,
            challenge = challenge,
            deviceId = deviceId,
            keyId = keyId
        )
        val bodyStr = buildJsonObject {
            put("deviceId", deviceId)
            put("keyId", keyId)
            put("attestation", signature)
            put("publicKey", toBase64Url(publicKeyBytes))
            put("platform", "android")
        }.toString()

        val request = Request.Builder()
            .url("$baseUrl/auth/attest")
            .post(bodyStr.toRequestBody(jsonMediaType))
            .build()

        val (statusCode, responseBody) = withContext(Dispatchers.IO) {
            val response = okHttpClient.newCall(request).execute()
            val code = response.code
            val body = response.body?.string().orEmpty()
            response.close()
            code to body
        }

        if (statusCode !in 200..299) {
            // Worker challenge map is isolate-local; retry when challenge is missing.
            if (responseBody.contains("No challenge found", ignoreCase = true)) return null
            return null
        }

        return json.decodeFromString(responseBody)
    }

    private suspend fun fetchChallenge(deviceId: String): String {
        val challengeUrl = "$baseUrl/auth/challenge".toHttpUrl()
            .newBuilder()
            .addQueryParameter("deviceId", deviceId)
            .build()

        val request = Request.Builder()
            .url(challengeUrl)
            .get()
            .build()

        val responseBody = withContext(Dispatchers.IO) {
            val response = okHttpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                response.close()
                throw Exception("Challenge failed: ${response.code}")
            }
            val body = response.body?.string()
            response.close()
            body ?: throw Exception("Empty challenge response")
        }

        val challenge = json.parseToJsonElement(responseBody)
            .jsonObject["challenge"]?.jsonPrimitive?.content
        return challenge ?: throw Exception("Missing challenge in response")
    }

    private fun getOrCreateKeystoreKeyPair(): KeyPair {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existingPrivate = keyStore.getKey(keyAlias, null)
        val existingPublic = keyStore.getCertificate(keyAlias)?.publicKey
        if (existingPrivate != null && existingPublic != null) {
            return KeyPair(existingPublic, existingPrivate as java.security.PrivateKey)
        }

        val keyGenerator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore"
        )
        val spec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
            .setUserAuthenticationRequired(false)
            .build()
        keyGenerator.initialize(spec)
        return keyGenerator.generateKeyPair()
    }

    private fun buildKeyId(publicKeyBytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(publicKeyBytes)
        return "android_${toBase64Url(digest)}"
    }

    private fun signChallenge(
        privateKey: PrivateKey,
        challenge: String,
        deviceId: String,
        keyId: String
    ): String {
        val payload = "$challenge:$deviceId:$keyId"
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(privateKey)
        signer.update(payload.toByteArray(StandardCharsets.UTF_8))
        return toBase64Url(signer.sign())
    }

    private fun toBase64Url(bytes: ByteArray): String =
        Base64.encodeToString(
            bytes,
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
        )

    private suspend fun refreshAccessToken(refreshToken: String) {
        val bodyStr = buildJsonObject { put("refreshToken", refreshToken) }.toString()
        val request = Request.Builder()
            .url("$baseUrl/auth/refresh")
            .post(bodyStr.toRequestBody(jsonMediaType))
            .build()

        val responseBody = withContext(Dispatchers.IO) {
            val response = okHttpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                response.close()
                throw Exception("Refresh failed: ${response.code}")
            }
            val body = response.body?.string()
            response.close()
            body ?: throw Exception("Empty refresh response")
        }

        val result = json.decodeFromString<RefreshTokenResponse>(responseBody)
        storage.save(accessTokenKey, result.accessToken)
        storage.save(tokenExpiryKey, (System.currentTimeMillis() + result.expiresIn * 1000L).toString())
    }

    private fun storeTokens(tokens: TokenResponse) {
        storage.save(accessTokenKey, tokens.accessToken)
        storage.save(refreshTokenKey, tokens.refreshToken)
        storage.save(tokenExpiryKey, (System.currentTimeMillis() + tokens.expiresIn * 1000L).toString())
    }

    private fun getTokenExpiry(): Long? = storage.read(tokenExpiryKey)?.toLongOrNull()

    private fun clearTokens() {
        storage.delete(accessTokenKey)
        storage.delete(refreshTokenKey)
        storage.delete(tokenExpiryKey)
    }
}
