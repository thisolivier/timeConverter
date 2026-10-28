package dev.thisolivier.timeconverter

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The outlined box: the field, then — once there is a conversion — a hairline
 * and the parsed source echoed back inside the same frame (item 18). Single
 * line so Done stays a submit, which is what bypasses the prompt debounce.
 */
@Composable
fun ConverterInputBox(
    fieldValue: TextFieldValue,
    sourceEchoLine: String?,
    focusRequester: FocusRequester,
    onFieldValueChange: (TextFieldValue) -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = LocalPosterColors.current
    PosterBox(modifier) {
        Column(Modifier.fillMaxWidth()) {
            BasicTextField(
                value = fieldValue,
                onValueChange = onFieldValueChange,
                singleLine = true,
                textStyle = PosterTypography.mono(21.sp).copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.None,
                    autoCorrectEnabled = false,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onSubmit() }),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester)
                    .semantics { contentDescription = "Time and places" },
                decorationBox = { innerTextField ->
                    if (fieldValue.text.isEmpty()) {
                        Text("12pm ET in London", style = PosterTypography.mono(21.sp), color = colors.quietInk)
                    }
                    innerTextField()
                },
            )
            if (sourceEchoLine != null) {
                PosterRule(Modifier.padding(top = 12.dp), thickness = 1.dp)
                Text(
                    sourceEchoLine,
                    style = PosterTypography.mono(12.5.sp, FontWeight.Normal),
                    color = colors.ink,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
        }
    }
}
