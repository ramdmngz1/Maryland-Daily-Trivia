# ============================================================
# Kotlinx Serialization
# ============================================================
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Keep companion objects and serializer methods on @Serializable classes
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclassmembers @kotlinx.serialization.Serializable class * {
    *** Companion;
    static ** serializer(...);
    static ** access$*(...);
}
-keepclasseswithmembers class **$$serializer { *; }
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }

# ============================================================
# Retrofit
# ============================================================
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions
-keepclassmembers,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

# Keep our Retrofit API interface (methods are accessed by reflection)
-keep interface com.copanostudios.texasdailytrivia.network.ApiService { *; }

# ============================================================
# OkHttp / Okio
# ============================================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ============================================================
# Android Keystore / Security Crypto
# ============================================================
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ============================================================
# Coroutines
# ============================================================
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ============================================================
# Jetpack Navigation Compose
# ============================================================
-dontwarn androidx.navigation.**

# ============================================================
# AdMob / Google Play Services
# ============================================================
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**

# ============================================================
# User Messaging Platform (UMP / Consent SDK)
# ============================================================
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.ump.**

# ============================================================
# Stack traces: preserve file/line info for crash reports
# ============================================================
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
