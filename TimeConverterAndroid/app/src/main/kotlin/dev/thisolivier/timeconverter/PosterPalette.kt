package dev.thisolivier.timeconverter

import androidx.compose.ui.graphics.Color

/**
 * The retro-poster palette from `docs/design/Time Converter.pdf`, matching the
 * Swift `GlassPalette`/poster tokens: cream paper, ink, rust accent. Dark mode
 * derives the same way the iOS side does. Typography is the system condensed
 * face until the design pass picks fonts for Android.
 */
object PosterPalette {
    val cream = Color(0xFFEBD3A9)
    val ink = Color(0xFF141210)
    val rust = Color(0xFFB5391F)
    val inkMuted = Color(0x99141210)

    val darkPaper = Color(0xFF141210)
    val darkInk = Color(0xFFEBD3A9)
    val darkInkMuted = Color(0x99EBD3A9)
}
