package dev.thisolivier.timeconverter

import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplayDriver
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplayState
import dev.thisolivier.timeconverter.core.presentation.PromptScheduler
import dev.thisolivier.timeconverter.core.presentation.ReplacementChip
import dev.thisolivier.timeconverter.core.presentation.ScheduledPrompt
import java.time.Instant
import java.time.ZoneId

/** The driver's debounce on the main looper, so the delayed prompt lands on the UI thread. */
object MainLooperPromptScheduler : PromptScheduler {
    private val handler = Handler(Looper.getMainLooper())

    override fun schedule(delayMillis: Long, action: () -> Unit): ScheduledPrompt {
        val runnable = Runnable(action)
        handler.postDelayed(runnable, delayMillis)
        return ScheduledPrompt { handler.removeCallbacks(runnable) }
    }
}

/**
 * The screen's platform state — the typed text and the driver's output, as
 * Compose state — and the one place that reads the clock and the device zone,
 * per call, so a zone change or midnight is picked up on the next keystroke.
 * All timing and wording stays in `:core`.
 */
class ConverterScreenModel(initialInput: String) {
    var fieldValue by mutableStateOf(TextFieldValue(initialInput, TextRange(initialInput.length)))
        private set
    var displayState by mutableStateOf<ConverterDisplayState>(ConverterDisplayState.Hint)
        private set

    private val driver = ConverterDisplayDriver(
        scheduler = MainLooperPromptScheduler,
        onDisplayStateChange = { displayState = it },
    )

    val input: String get() = fieldValue.text

    /**
     * The last arrival that took focus (or that arrived while Clocks was up).
     * Lives here, not in the screen, so switching back to Convert — which
     * re-composes the screen — does not count as an arrival and raise the keyboard.
     */
    var handledArrivalCount = -1

    init {
        // Launch (and the debug prefill) bypasses the debounce, so a prefilled
        // screenshot shows its prompt and chips rather than an empty hint.
        showWithoutWaiting()
    }

    fun onFieldValueChange(newValue: TextFieldValue) {
        val textChanged = newValue.text != fieldValue.text
        fieldValue = newValue
        if (textChanged) driver.inputDidChange(newValue.text, Instant.now(), ZoneId.systemDefault())
    }

    /** Submit: an action, not typing. */
    fun showWithoutWaiting() = driver.showWithoutWaiting(input, Instant.now(), ZoneId.systemDefault())

    /** A chip rewrites the sentence; the re-parse follows from the sentence. Cursor to the end. */
    fun apply(chip: ReplacementChip) {
        val rewritten = driver.apply(chip, input, Instant.now(), ZoneId.systemDefault())
        fieldValue = TextFieldValue(rewritten, TextRange(rewritten.length))
    }
}
