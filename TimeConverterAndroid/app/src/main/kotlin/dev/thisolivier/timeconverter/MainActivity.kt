package dev.thisolivier.timeconverter

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge

/**
 * The one activity: edge-to-edge, hands everything to Compose.
 *
 * `initialInput` (a string extra, `scripts/run-android.sh --input "…"`) prefills
 * the field so the emulator can be driven to a given state for screenshots —
 * the Android twin of the iOS `-initialInput` launch argument.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val initialInput = intent.getStringExtra("initialInput").orEmpty()
        setContent {
            ConverterScreen(initialInput = initialInput)
        }
    }
}
