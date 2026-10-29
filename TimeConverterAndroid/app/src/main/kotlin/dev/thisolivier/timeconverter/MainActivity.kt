package dev.thisolivier.timeconverter

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableIntStateOf

/**
 * The one activity: edge-to-edge, hands everything to Compose.
 *
 * `initialInput` (a string extra, `scripts/run-android.sh --input "…"`) prefills
 * the field so the emulator can be driven to a given state for screenshots —
 * the Android twin of the iOS `-initialInput` launch argument.
 *
 * `arrivalCount` ticks in `onStart`: launch and a genuine return from the
 * background, but not a mere `onPause`/`onResume` (a dialog, multi-window
 * focus) — the same line iOS draws between `.background` and `.inactive`.
 * It also ticks for a "Convert a time" launch (tile, shortcut) that reaches a
 * live activity through `onNewIntent`, and when the one-time add-tile dialog
 * closes — each of those wants the field focused and the keyboard up.
 * `launchRequestCount` ticks only for the tile/shortcut launch, which also
 * brings the Convert tab forward (`RootScreen`).
 *
 * DEBUG builds also read the QA extras in `DebugLaunchOptions` (`favourites`,
 * `selectedTab`, `clockOffsetMinutes`); the favourites seed is applied here,
 * once per fresh launch.
 */
class MainActivity : ComponentActivity() {
    private val arrivalCount = mutableIntStateOf(0)
    /** Ticks for each "Convert a time" launch reaching a live activity: Convert comes forward. */
    private val launchRequestCount = mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val initialInput = intent.getStringExtra("initialInput").orEmpty()
        val debugLaunchOptions = DebugLaunchOptions.read(this, intent)
        val favouritesModel = FavouritesModel.forContext(this)
        if (savedInstanceState == null) debugLaunchOptions.seededFavourites?.let(favouritesModel::replaceAll)
        setContent {
            RootScreen(
                initialInput = initialInput,
                debugLaunchOptions = debugLaunchOptions,
                favouritesModel = favouritesModel,
                arrivalCount = arrivalCount.intValue,
                launchRequestCount = launchRequestCount.intValue,
            )
        }
        ConvertTimeLaunch.publishLauncherShortcut(this)
        val isScriptedLaunch = initialInput.isNotEmpty() || debugLaunchOptions.isScripted
        window.decorView.post {
            QuickSettingsTileOnboarding.offerOnce(this, isScriptedLaunch = isScriptedLaunch) {
                arrivalCount.intValue += 1
            }
        }
    }

    override fun onStart() {
        super.onStart()
        arrivalCount.intValue += 1
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (ConvertTimeLaunch.asksForFocus(intent)) {
            launchRequestCount.intValue += 1
            arrivalCount.intValue += 1
        }
    }
}
