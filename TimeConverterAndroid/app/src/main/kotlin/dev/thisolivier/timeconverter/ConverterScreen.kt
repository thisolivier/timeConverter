package dev.thisolivier.timeconverter

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.engine.ZoneNames
import dev.thisolivier.timeconverter.core.parsing.InterimInputParser
import java.time.Instant
import java.time.ZoneId

/**
 * The single screen: input box with the parsed echo inside it, a rule, and the
 * poster-scale result. Behaviour lives in `:core`; this file only lays out
 * strings, the same discipline as the SwiftUI shells.
 */
@Composable
fun ConverterScreen(initialInput: String = "") {
    val isDark = isSystemInDarkTheme()
    val paper = if (isDark) PosterPalette.darkPaper else PosterPalette.cream
    val ink = if (isDark) PosterPalette.darkInk else PosterPalette.ink
    val inkMuted = if (isDark) PosterPalette.darkInkMuted else PosterPalette.inkMuted

    var input by remember { mutableStateOf(initialInput) }
    val focusRequester = remember { FocusRequester() }
    // Autofocus on launch (item 10): launch-to-typing is zero taps.
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    val outcome = InterimInputParser.parse(input, Instant.now(), ZoneId.systemDefault())

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(paper)
            .safeDrawingPadding()
            .imePadding()
            .padding(horizontal = 24.dp, vertical = 16.dp)
    ) {
        Text(
            "TIME CONVERTER",
            color = ink,
            fontSize = 34.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 2.sp,
        )
        Spacer(Modifier.height(20.dp))
        OutlinedTextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
            placeholder = { Text("12pm ET in London", color = inkMuted) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.None,
                autoCorrectEnabled = false,
                imeAction = ImeAction.Done,
            ),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = ink, unfocusedTextColor = ink,
                focusedBorderColor = ink, unfocusedBorderColor = ink,
                cursorColor = PosterPalette.rust,
            ),
            supportingText = {
                if (outcome is InterimInputParser.Outcome.Converted) {
                    val source = outcome.result.source
                    Text("${source.placeDescription} · ${source.uppercasedTime}", color = inkMuted, fontFamily = FontFamily.Monospace)
                }
            },
        )
        Spacer(Modifier.height(24.dp))
        HorizontalDivider(color = ink, thickness = 2.dp)
        Spacer(Modifier.height(24.dp))

        when (outcome) {
            InterimInputParser.Outcome.Hint ->
                Text("Type a time to convert", color = inkMuted, fontFamily = FontFamily.Monospace)

            is InterimInputParser.Outcome.Problem ->
                Text(outcome.message, color = PosterPalette.rust, fontFamily = FontFamily.Monospace)

            is InterimInputParser.Outcome.Converted -> {
                val result = outcome.result
                Text(
                    result.target.headerDescription.uppercase(),
                    color = inkMuted, fontFamily = FontFamily.Monospace, letterSpacing = 2.sp, fontSize = 13.sp,
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(result.target.clockDigits, color = ink, fontSize = 96.sp, fontWeight = FontWeight.Black, lineHeight = 96.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(result.target.uppercasedMeridiem, color = PosterPalette.rust, fontSize = 28.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(bottom = 14.dp))
                }
                val zoneLine = listOfNotNull(ZoneNames.zoneDetailLine(result.target).ifEmpty { null }, result.dayRolloverNote).joinToString(" · ")
                Text(zoneLine.uppercase(), color = inkMuted, fontFamily = FontFamily.Monospace, letterSpacing = 1.sp, fontSize = 12.sp)
                Spacer(Modifier.height(16.dp))
                Text(result.relativeOffsetSentence, color = ink, fontFamily = FontFamily.Monospace, fontSize = 14.sp)
            }
        }
    }
}
