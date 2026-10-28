package dev.thisolivier.timeconverter.core.presentation

import java.time.Instant
import java.time.ZoneId

/**
 * Runs `action` after `delayMillis` unless cancelled first. The driver's only
 * window onto time, so the JVM tests can drive it with a fake clock and the app
 * with the main looper.
 */
fun interface PromptScheduler {
    fun schedule(delayMillis: Long, action: () -> Unit): ScheduledPrompt
}

fun interface ScheduledPrompt {
    fun cancel()
}

/**
 * Owns *when* the output area changes (backlog item 8). Port of Swift
 * `ConverterDisplayDriver`.
 *
 * **Results are instant; prompts wait.** A conversion never lags a keystroke;
 * a prompt is held for [promptDelayMillis] (600 ms, decided 2026-10-21) and the
 * quiet hint shows meanwhile — never a stale conversion under edited text.
 *
 * Launch, submit and chip taps go through [showWithoutWaiting]: the user acted
 * rather than typed and gets the next prompt at once.
 *
 * Not thread-safe by design: call it from the UI thread, and give it a
 * scheduler that calls back on the UI thread.
 */
class ConverterDisplayDriver(
    private val scheduler: PromptScheduler,
    private val presenter: ConverterPresenter = ConverterPresenter(),
    private val promptDelayMillis: Long = DEFAULT_PROMPT_DELAY_MILLIS,
    private val onDisplayStateChange: (ConverterDisplayState) -> Unit = {},
) {
    companion object {
        const val DEFAULT_PROMPT_DELAY_MILLIS: Long = 600
    }

    var displayState: ConverterDisplayState = ConverterDisplayState.Hint
        private set(newState) {
            field = newState
            onDisplayStateChange(newState)
        }

    private var pendingPrompt: ScheduledPrompt? = null

    /**
     * The input most recently shown through a bypass. Guards against the
     * field's ordinary change notification arriving *after* a chip tap and
     * re-hiding the prompt the tap just revealed.
     */
    private var inputShownWithoutWaiting: String? = null

    /** The debounced path: every keystroke. */
    fun inputDidChange(rawInput: String, now: Instant, localZone: ZoneId) {
        if (rawInput == inputShownWithoutWaiting) return
        inputShownWithoutWaiting = null
        cancelPendingPrompt()

        when (val evaluation = presenter.evaluate(rawInput, now, localZone)) {
            is ConverterPresenter.Evaluation.Prompted -> {
                displayState = ConverterDisplayState.Hint
                pendingPrompt = scheduler.schedule(promptDelayMillis) {
                    pendingPrompt = null
                    displayState = ConverterDisplayState.Problem(presenter.problem(evaluation.prompt))
                }
            }
            else -> displayState = presenter.displayState(evaluation)
        }
    }

    /** Launch, submit, and the aftermath of a chip tap: show what the input produces, now. */
    fun showWithoutWaiting(rawInput: String, now: Instant, localZone: ZoneId) {
        cancelPendingPrompt()
        inputShownWithoutWaiting = rawInput
        displayState = presenter.displayState(rawInput, now, localZone)
    }

    /** Applies a chip and returns the rewritten sentence for the caller to store. */
    fun apply(chip: ReplacementChip, rawInput: String, now: Instant, localZone: ZoneId): String {
        val rewrittenInput = chip.applied(rawInput)
        showWithoutWaiting(rewrittenInput, now, localZone)
        return rewrittenInput
    }

    private fun cancelPendingPrompt() {
        pendingPrompt?.cancel()
        pendingPrompt = null
    }
}
