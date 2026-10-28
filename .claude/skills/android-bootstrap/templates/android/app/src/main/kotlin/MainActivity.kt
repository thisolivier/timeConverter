package __APPLICATION_ID__

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import __APPLICATION_ID__.core.Greeting

/**
 * The one activity: edge-to-edge, hands everything to Compose.
 *
 * `initialInput` (a string extra, `scripts/run-android.sh --input "…"`) lets
 * the headless emulator be driven to a given state for screenshots. The
 * hello-world screen just echoes it; a real app prefills its input with it.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val initialInput = intent.getStringExtra("initialInput").orEmpty()
        setContent {
            val colorScheme = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme()
            MaterialTheme(colorScheme = colorScheme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    HelloScreen(initialInput = initialInput)
                }
            }
        }
    }
}

@Composable
private fun HelloScreen(initialInput: String) {
    Column(
        modifier = Modifier.fillMaxSize().safeDrawingPadding().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(Greeting.headline("__APP_NAME__"), style = MaterialTheme.typography.headlineMedium)
        if (initialInput.isNotEmpty()) {
            Text(initialInput, style = MaterialTheme.typography.bodyLarge)
        }
    }
}
