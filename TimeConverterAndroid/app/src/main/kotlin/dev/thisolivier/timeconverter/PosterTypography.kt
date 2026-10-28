package dev.thisolivier.timeconverter

import android.graphics.Typeface
import android.os.Build
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/**
 * The poster's two faces, from system fonts until the design pass bundles
 * real ones: the heaviest condensed sans the platform has for display type
 * (Swift: `.black` + `.compressed`), and monospace for everything else.
 * Mirrors Swift `PosterTypography`, including `posterLabel`'s 0.16 em tracking.
 */
object PosterTypography {
    private val condensedTypeface: Typeface = run {
        val condensed = Typeface.create("sans-serif-condensed", Typeface.BOLD)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Typeface.create(condensed, 900, false) else condensed
    }

    val displayFamily: FontFamily = FontFamily(condensedTypeface)
    val monoFamily: FontFamily = FontFamily.Monospace

    /** Poster-scale type; tight line box, slightly pinched tracking to read as compressed. */
    fun display(size: TextUnit): TextStyle = TextStyle(
        fontFamily = displayFamily,
        fontWeight = FontWeight.Black,
        fontSize = size,
        lineHeight = 0.95.em,
        letterSpacing = (-0.02).em,
        // Trim the line box to the type itself, so stacked display lines sit as tight as the design's.
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both),
    )

    fun mono(size: TextUnit, weight: FontWeight = FontWeight.Medium): TextStyle = TextStyle(
        fontFamily = monoFamily,
        fontWeight = weight,
        fontSize = size,
    )

    /** Uppercase letterspaced label; the caller uppercases the string. */
    fun label(size: TextUnit = 13.sp, tracking: Double = 0.16): TextStyle =
        mono(size).copy(letterSpacing = tracking.em)
}
