package com.copanostudios.marylanddailytrivia.network

object NetworkConfig {
    const val API_HOST = "maryland-trivia-contest.f22682jcz6.workers.dev"
    const val BASE_URL = "https://$API_HOST/"

    val allowedHosts: Set<String> = setOf(API_HOST)
}

