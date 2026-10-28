package dev.thisolivier.timeconverter

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
 */
class MainActivity : ComponentActivity() {
    private val arrivalCount = mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val initialInput = intent.getStringExtra("initialInput").orEmpty()
        setContent {
            ConverterScreen(initialInput = initialInput, arrivalCount = arrivalCount.intValue)
        }
    }

    override fun onStart() {
        super.onStart()
        arrivalCount.intValue += 1
    }
}
