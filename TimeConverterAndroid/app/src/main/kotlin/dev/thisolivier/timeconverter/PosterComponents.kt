package dev.thisolivier.timeconverter

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * The poster's furniture — port of the iPhone's `PosterComponents.swift` and
 * the shared `PosterArrow` shape: 2 dp rules, the rule-and-arrow band, the
 * square outlined input box.
 */

/** The design's horizontal rules: 2 dp between bands, 1 dp inside the input box. */
@Composable
fun PosterRule(modifier: Modifier = Modifier, thickness: Dp = 2.dp) {
    Box(modifier.fillMaxWidth().height(thickness).background(LocalPosterColors.current.ink))
}

/** Two rules with a rust down-arrow floating in the gap. */
@Composable
fun PosterArrowSeparator(modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PosterRule(Modifier.weight(1f))
        PosterArrow(Modifier.size(width = 26.dp, height = 32.dp))
        PosterRule(Modifier.weight(1f))
    }
}

/**
 * The design's stroked arrow, against its own `0 0 26 32` viewBox:
 * stem `M13 0 V26`, head `M2 16 L13 28 L24 16`, 5-unit butt-capped stroke.
 */
@Composable
fun PosterArrow(modifier: Modifier = Modifier) {
    val accent = LocalPosterColors.current.accent
    Canvas(modifier) {
        val horizontalScale = size.width / 26f
        val verticalScale = size.height / 32f
        val path = Path().apply {
            moveTo(13f * horizontalScale, 0f)
            lineTo(13f * horizontalScale, 26f * verticalScale)
            moveTo(2f * horizontalScale, 16f * verticalScale)
            lineTo(13f * horizontalScale, 28f * verticalScale)
            lineTo(24f * horizontalScale, 16f * verticalScale)
        }
        drawPath(path, accent, style = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Butt, join = StrokeJoin.Miter))
    }
}

/** A 2 dp ink rectangle, square corners — a radius here would make the poster look like a form. */
@Composable
fun PosterBox(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier
            .fillMaxWidth()
            .border(2.dp, LocalPosterColors.current.ink)
            .padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 12.dp),
        content = content,
    )
}
