package com.copanostudios.marylanddailytrivia.ads

import com.copanostudios.marylanddailytrivia.BuildConfig

/**
 * AdMob runtime config.
 * Debug uses Google's test IDs. Release IDs are injected via Gradle properties.
 */
object AdMobConfig {
    val bannerAdUnitId: String
        get() = BuildConfig.ADMOB_BANNER_AD_UNIT_ID
}
