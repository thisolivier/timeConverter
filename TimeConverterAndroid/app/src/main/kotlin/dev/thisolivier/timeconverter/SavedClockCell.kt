package dev.thisolivier.timeconverter

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.worldclock.WorldClockRow

/**
 * The sizes for one of the three grid densities (item 37) — the iPhone's
 * `SavedCellDensity`, point for point. Every cell in a layout shares one
 * numeral size; a numeral that still will not fit its column scales down
 * alone (`TextAutoSize`), as the result band's does.
 */
class SavedCellDensity(columnCount: Int) {
    private val index = columnCount.coerceIn(1, 3) - 1
    val labelSize = listOf(12, 11, 10)[index].sp
    val clockSize = listOf(92, 56, 40)[index]
    val meridiemSize = listOf(28, 18, 13)[index]
    val captionSize = listOf(15, 13, 11)[index].sp
    val horizontalPadding: Dp = listOf(28, 20, 14)[index].dp
    val verticalPadding: Dp = listOf(22, 18, 14)[index].dp
    /** The three-column layout has no room for `8 hours behind`, nor for `LONDON (LOCAL)`. */
    val usesShortForms = columnCount >= 3
}

/**
 * One clock in the Saved grid: the place label, the numerals with a smaller
 * meridiem on the same baseline, and a caption — the offset phrase, or `Local
 * time` on the local clock. Logic-free, like `PosterResultSection`.
 */
@Composable
fun SavedClockCell(clock: WorldClockRow, density: SavedCellDensity, modifier: Modifier = Modifier) {
    val colors = LocalPosterColors.current
    val caption = when {
        clock.isLocal -> "Local time"
        density.usesShortForms -> clock.shortOffsetPhrase
        else -> clock.offsetPhrase
    }
    Column(
        modifier
            .padding(horizontal = density.horizontalPadding, vertical = density.verticalPadding)
            .semantics(mergeDescendants = true) { contentDescription = "${clock.placeName}, ${clock.clockDigits} ${clock.meridiem}, $caption" },
    ) {
        Text(
            (if (density.usesShortForms) clock.compactPlaceName else clock.placeName).uppercase(),
            style = PosterTypography.label(density.labelSize),
            color = colors.ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        BasicText(
            buildAnnotatedString {
                append(clock.clockDigits)
                withStyle(SpanStyle(fontSize = density.meridiemSize.sp)) { append(" ${clock.meridiem}") }
            },
            style = PosterTypography.display(density.clockSize.sp).copy(color = colors.ink),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(minFontSize = (density.clockSize * 0.6f).sp, maxFontSize = density.clockSize.sp, stepSize = 1.sp),
            modifier = Modifier.padding(top = 4.dp),
        )
        Text(
            caption,
            style = PosterTypography.mono(density.captionSize, FontWeight.Normal),
            color = colors.quietInk,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}
