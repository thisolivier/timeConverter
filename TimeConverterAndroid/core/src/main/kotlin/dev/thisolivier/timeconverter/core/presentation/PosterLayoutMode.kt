package dev.thisolivier.timeconverter.core.presentation

/**
 * Item 19's keyboard choreography, as a pure decision — port of Swift
 * `PosterLayoutMode`. The view owns the observation (is the IME up?) and the
 * animation; the rule lives here where a test can see it.
 *
 * Collapse only when the user is typing into something: an empty field with
 * the keyboard up is the opening state and keeps the full poster.
 */
enum class PosterLayoutMode {
    /** Title, top rule, full-scale numerals. */
    Full,
    /** Title and top rule gone, numerals a step down, so everything fits above the keyboard. */
    Compact;

    /** The title and the rule under it travel together. */
    val showsTitleBlock: Boolean get() = this == Full

    val usesCompactResultType: Boolean get() = this == Compact

    companion object {
        fun mode(rawInput: String, keyboardIsVisible: Boolean): PosterLayoutMode =
            mode(hasInput = rawInput.isNotBlank(), keyboardIsVisible = keyboardIsVisible)

        fun mode(hasInput: Boolean, keyboardIsVisible: Boolean): PosterLayoutMode =
            if (hasInput && keyboardIsVisible) Compact else Full
    }
}
