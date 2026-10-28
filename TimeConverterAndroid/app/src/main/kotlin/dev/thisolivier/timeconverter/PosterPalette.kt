package dev.thisolivier.timeconverter

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * The poster palette — the values of Swift `TimeConverterUI.PosterPalette`,
 * light and dark, one-for-one: cream paper and ink, inverted for dark, with a
 * brighter rust in the dark so it holds its contrast on near-black.
 */
data class PosterColors(
    val paper: Color,
    val ink: Color,
    /** The arrow and pressed chips. */
    val accent: Color,
    /** Rust for text (prompts, the DST note) — a shade darker than `accent` in light mode for legibility. */
    val accentText: Color,
) {
    /** Placeholder and the hint: ink at 55 %. */
    val quietInk: Color get() = ink.copy(alpha = 0.55f)

    companion object {
        val light = PosterColors(
            paper = Color(0xFFEBD3A9),
            ink = Color(0xFF141210),
            accent = Color(0xFFB5391F),
            accentText = Color(0xFF9E3019),
        )
        val dark = PosterColors(
            paper = Color(0xFF141210),
            ink = Color(0xFFEBD3A9),
            accent = Color(0xFFE0633F),
            accentText = Color(0xFFE0633F),
        )
    }
}

val LocalPosterColors = staticCompositionLocalOf { PosterColors.light }

/** Follows the system appearance. */
@Composable
fun systemPosterColors(): PosterColors = if (isSystemInDarkTheme()) PosterColors.dark else PosterColors.light
