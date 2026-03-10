package com.copanostudios.marylanddailytrivia

import android.os.Bundle
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowInsetsControllerCompat
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.copanostudios.marylanddailytrivia.ui.screens.HomeScreen
import com.copanostudios.marylanddailytrivia.ui.screens.LeaderboardScreen
import com.copanostudios.marylanddailytrivia.ui.screens.LiveTriviaScreen
import com.copanostudios.marylanddailytrivia.ui.screens.SettingsScreen
import com.copanostudios.marylanddailytrivia.ui.theme.MarylandDailyTriviaTheme
import com.google.android.gms.ads.MobileAds
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize service locator
        AppContainer.init(applicationContext)

        // Request UMP consent (required for EU/EEA AdMob compliance), then initialize AdMob.
        // MobileAds.initialize() is intentionally called only after consent is resolved.
        val consentInfo = UserMessagingPlatform.getConsentInformation(this)
        val params = ConsentRequestParameters.Builder()
            .setTagForUnderAgeOfConsent(false)
            .build()
        consentInfo.requestConsentInfoUpdate(this, params, {
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(this) {
                MobileAds.initialize(this)
            }
        }, {
            // Consent info update failed — initialize AdMob anyway so ads are not permanently broken
            MobileAds.initialize(this)
        })

        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars = false
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightNavigationBars = false

        setContent {
            var showLaunchOverlay by remember { mutableStateOf(true) }

            LaunchedEffect(Unit) {
                delay(650)
                showLaunchOverlay = false
            }

            Box(modifier = Modifier.fillMaxSize().background(Color(0xFF1A0D03))) {
                MarylandDailyTriviaTheme {
                    MarylandDailyTriviaApp(modifier = Modifier.fillMaxSize())
                }

                if (showLaunchOverlay) {
                    LaunchOverlay()
                }
            }
        }
    }
}

@Composable
private fun BoxScope.LaunchOverlay() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF1A0D03)),
        contentAlignment = Alignment.Center
    ) {
        Image(
            painter = painterResource(id = R.drawable.splash_logo),
            contentDescription = null,
            modifier = Modifier.size(230.dp)
        )
    }
}

@Composable
fun MarylandDailyTriviaApp(modifier: Modifier = Modifier) {
    val navController: NavHostController = rememberNavController()

    // Settings is handled as overlay state to avoid NavHost back-stack complications
    var showSettings by rememberSaveable { mutableStateOf(false) }

    if (showSettings) {
        SettingsScreen(onDismiss = { showSettings = false })
        return
    }

    NavHost(
        navController = navController,
        startDestination = "home",
        modifier = modifier
    ) {
        composable("home") {
            HomeScreen(
                onStartQuiz = { navController.navigate("live_trivia") },
                onShowSettings = { showSettings = true },
                onShowLeaderboard = { navController.navigate("leaderboard") }
            )
        }

        composable("live_trivia") {
            LiveTriviaScreen(
                onExit = { navController.popBackStack() }
            )
        }

        composable(
            route = "leaderboard?roundId={roundId}",
            arguments = listOf(
                navArgument("roundId") {
                    type = NavType.StringType
                    nullable = true
                    defaultValue = null
                }
            )
        ) { backStackEntry ->
            val roundId = backStackEntry.arguments?.getString("roundId")
            LeaderboardScreen(roundId = roundId)
        }

    }
}
