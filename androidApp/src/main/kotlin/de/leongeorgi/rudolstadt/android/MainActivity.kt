@file:OptIn(androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)

package de.leongeorgi.rudolstadt.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.os.BundleCompat
import androidx.core.view.WindowCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

class MainActivity : ComponentActivity() {
    private var incoming by mutableStateOf<Intent?>(null)
    private lateinit var model: AppModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        incoming =
            if (savedInstanceState == null) intent
            else BundleCompat.getParcelable(savedInstanceState, "pendingIntent", Intent::class.java)
        model = ViewModelProvider(this)[AppModel::class.java]
        setContent {
            val state by model.state.collectAsStateWithLifecycle()
            val context = LocalContext.current
            val dark =
                when (state.settings.theme) {
                    "dark" -> true
                    "light" -> false
                    else -> isSystemInDarkTheme()
                }
            val colors =
                if (state.settings.dynamicColor && android.os.Build.VERSION.SDK_INT >= 31) {
                    if (dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
                } else if (dark) FestivalDarkColors else FestivalLightColors
            SideEffect {
                WindowCompat.getInsetsController(window, window.decorView).apply {
                    isAppearanceLightNavigationBars = !dark
                }
            }
            MaterialExpressiveTheme(
                colorScheme = colors,
                motionScheme = MotionScheme.expressive(),
            ) {
                val lifecycle = LocalLifecycleOwner.current.lifecycle
                LaunchedEffect(lifecycle) {
                    lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
                        while (isActive) {
                            model.onForeground()
                            delay(60_000)
                        }
                    }
                }
                AppRoot(model, state, incoming) { incoming = null }
            }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putParcelable("pendingIntent", incoming)
        super.onSaveInstanceState(outState)
    }

    override fun onStart() {
        super.onStart()
        model.mapForeground(true)
    }

    override fun onStop() {
        model.mapForeground(false)
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        incoming = intent
    }
}
