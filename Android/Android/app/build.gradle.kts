plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

val debugAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val debugBannerAdUnitId = "ca-app-pub-3940256099942544/6300978111"

val releaseAdmobAppId = (project.findProperty("ADMOB_ANDROID_APP_ID") as String?) ?: debugAdmobAppId
val releaseBannerAdUnitId = (project.findProperty("ADMOB_ANDROID_BANNER_ID") as String?) ?: debugBannerAdUnitId

android {
    namespace = "com.copanostudios.marylanddailytrivia"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.copanostudios.marylanddailytrivia"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        manifestPlaceholders["admobAppId"] = debugAdmobAppId

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            buildConfigField("String", "ADMOB_BANNER_AD_UNIT_ID", "\"$debugBannerAdUnitId\"")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            manifestPlaceholders["admobAppId"] = releaseAdmobAppId
            buildConfigField("String", "ADMOB_BANNER_AD_UNIT_ID", "\"$releaseBannerAdUnitId\"")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)

    // Networking
    implementation(libs.retrofit)
    implementation(libs.retrofit.kotlinx.serialization)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)

    // Serialization
    implementation(libs.kotlinx.serialization.json)

    // Navigation
    implementation(libs.navigation.compose)

    // Security
    implementation(libs.security.crypto)

    // Coroutines
    implementation(libs.coroutines.android)

    // ViewModel + Compose
    implementation(libs.lifecycle.viewmodel.compose)

    // AdMob
    implementation(libs.play.services.ads)
    // User Messaging Platform (GDPR/CCPA consent)
    implementation(libs.user.messaging.platform)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
