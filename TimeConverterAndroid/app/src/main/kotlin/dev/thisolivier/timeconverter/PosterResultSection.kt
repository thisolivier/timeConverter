package dev.thisolivier.timeconverter

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplay
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplayState
import dev.thisolivier.timeconverter.core.presentation.ConverterProblem
import dev.thisolivier.timeconverter.core.presentation.PosterLayoutMode
import dev.thisolivier.timeconverter.core.presentation.ReplacementChip

/**
 * Everything below the arrow. A `when` over [ConverterDisplayState] and
 * nothing else — every string arrives pre-rendered. Port of the iPhone's
 * `PosterResultSection.swift`, sizes included.
 */
@Composable
fun PosterResultSection(
    displayState: ConverterDisplayState,
    layoutMode: PosterLayoutMode,
    onChipTap: (ReplacementChip) -> Unit,
    modifier: Modifier = Modifier,
) {
    when (displayState) {
        ConverterDisplayState.Hint -> Text(
            "Type a time to convert",
            style = PosterTypography.mono(14.sp, FontWeight.Normal),
            color = LocalPosterColors.current.quietInk,
            modifier = modifier,
        )
        is ConverterDisplayState.Converted -> ConvertedBand(displayState.display, layoutMode, modifier)
        is ConverterDisplayState.Problem -> ProblemBand(displayState.problem, onChipTap, modifier)
    }
}

/**
 * Two deliberate sizes rather than free scaling (item 19): 140 sp full, 92 sp
 * compact, the meridiem in proportion. Auto-size only ever shrinks a long
 * `12:30` to fit the width, as Swift's `minimumScaleFactor` does.
 */
private const val FULL_CLOCK_SIZE = 140
private const val COMPACT_CLOCK_SIZE = 92
private const val MERIDIEM_TO_CLOCK_RATIO = 40.0 / 140.0

@Composable
private fun ConvertedBand(display: ConverterDisplay, layoutMode: PosterLayoutMode, modifier: Modifier) {
    val colors = LocalPosterColors.current
    val clockSize = if (layoutMode.usesCompactResultType) COMPACT_CLOCK_SIZE else FULL_CLOCK_SIZE
    Column(modifier.fillMaxWidth()) {
        Text(display.targetPlaceLabel.uppercase(), style = PosterTypography.label(14.sp), color = colors.ink)

        val clockText = buildAnnotatedString {
            append(display.targetClockDigits)
            withStyle(SpanStyle(fontSize = MERIDIEM_TO_CLOCK_RATIO.em)) {
                append(" ")
                append(display.targetMeridiem)
            }
        }
        BasicText(
            clockText,
            style = PosterTypography.display(clockSize.sp).copy(color = colors.ink),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(minFontSize = (clockSize * 0.3).sp, maxFontSize = clockSize.sp, stepSize = 2.sp),
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
        )

        // Hidden when empty (GMT/UTC) so a blank line doesn't leave the rule floating.
        if (display.targetZoneLine.isNotEmpty()) {
            Text(
                display.targetZoneLine.uppercase(),
                style = PosterTypography.label(13.sp, tracking = 0.10),
                color = colors.ink,
                // Halved from 6 (item 21): a caption on the numerals, not a separate thing.
                modifier = Modifier.padding(top = 3.dp),
            )
        }

        // Halved from 18, same instruction.
        PosterRule(Modifier.padding(top = 9.dp))

        Text(
            display.footerSentence,
            style = PosterTypography.mono(14.sp, FontWeight.Normal),
            color = colors.ink,
            modifier = Modifier.padding(top = 14.dp),
        )

        display.daylightSavingNote?.let { note ->
            Text(
                note,
                style = PosterTypography.mono(13.sp, FontWeight.Normal),
                color = colors.accentText,
                modifier = Modifier.padding(top = 10.dp),
            )
        }
    }
}

@Composable
private fun ProblemBand(problem: ConverterProblem, onChipTap: (ReplacementChip) -> Unit, modifier: Modifier) {
    val accentText = LocalPosterColors.current.accentText
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("CAN'T CONVERT YET", style = PosterTypography.label(13.sp), color = accentText)
        Text(
            problem.message,
            style = PosterTypography.mono(15.sp, FontWeight.Normal),
            color = accentText,
        )
        if (problem.chips.isNotEmpty()) PromptChipRow(problem.chips, onChipTap)
    }
}

