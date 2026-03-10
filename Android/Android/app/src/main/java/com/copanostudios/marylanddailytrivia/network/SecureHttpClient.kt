package com.copanostudios.marylanddailytrivia.network

import com.copanostudios.marylanddailytrivia.BuildConfig
import okhttp3.CacheControl
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import java.util.concurrent.TimeUnit

/**
 * OkHttp client equivalent to iOS SecureSession:
 * - No cache (force-network)
 * - Host allowlist (only maryland-trivia-contest.f22682jcz6.workers.dev over HTTPS)
 * - 10s connect timeout, 30s read timeout
 * - No cookies
 */
object SecureHttpClient {

    private val allowedHosts = setOf("maryland-trivia-contest.f22682jcz6.workers.dev")

    /** Interceptor that enforces HTTPS + host allowlist */
    private val hostAllowlistInterceptor = Interceptor { chain ->
        val request = chain.request()
        val url = request.url
        require(url.scheme == "https") { "Only HTTPS requests are allowed" }
        require(url.host in allowedHosts) { "Host not in allowlist: ${url.host}" }
        chain.proceed(request)
    }

    /** Interceptor that forces no-cache on every request */
    private val noCacheInterceptor = Interceptor { chain ->
        val request = chain.request().newBuilder()
            .cacheControl(CacheControl.FORCE_NETWORK)
            .build()
        chain.proceed(request)
    }

    val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .addInterceptor(hostAllowlistInterceptor)
            .addInterceptor(noCacheInterceptor)
            .apply {
                if (BuildConfig.DEBUG) {
                    addInterceptor(HttpLoggingInterceptor().apply {
                        level = HttpLoggingInterceptor.Level.BASIC
                    })
                }
            }
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .cache(null)
            .build()
    }
}
