package dev.thisolivier.timeconverter

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplay
import dev.thisolivier.timeconverter.core.presentation.ConverterDisplayState
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination

/**
 * The sheet behind the Saved tab's `+` (item 37): type a place the way you
 * would on the Convert tab — `Tokyo`, `ET`, `Portland Oregon` — and save it.
 * The Convert tab's own resolution, through a second `ConverterScreenModel`:
 * a bare place converts, an ambiguous one prompts with the same chips, a
 * misspelt one gets the same did-you-mean; what the star would store is what
 * `Add` saves. Port of the iPhone's `AddSavedPlaceSheet`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSavedPlaceSheet(favouritesModel: FavouritesModel, initialText: String, onDismiss: () -> Unit) {
    val model = remember { ConverterScreenModel(initialText) }
    val focusRequester = remember { FocusRequester() }
    val colors = LocalPosterColors.current
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.paper,
        contentColor = colors.ink,
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 28.dp).padding(bottom = 40.dp).imePadding()) {
            Text("ADD A PLACE", style = PosterTypography.label(12.sp), color = colors.ink)
            PosterBox(Modifier.padding(top = 10.dp)) {
                BasicTextField(
                    value = model.fieldValue,
                    onValueChange = model::onFieldValueChange,
                    singleLine = true,
                    textStyle = PosterTypography.mono(21.sp).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { model.showWithoutWaiting() }),
                    modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
                    decorationBox = { innerTextField ->
                        if (model.fieldValue.text.isEmpty()) {
                            Text("Tokyo, ET, Portland Oregon", style = PosterTypography.mono(21.sp), color = colors.quietInk)
                        }
                        innerTextField()
                    },
                )
            }
            Column(Modifier.padding(top = 22.dp)) {
                when (val state = model.displayState) {
                    ConverterDisplayState.Hint -> Text("A city, a country or a zone code.", style = PosterTypography.mono(14.sp, FontWeight.Normal), color = colors.quietInk)
                    is ConverterDisplayState.Converted -> {
                        val destination = state.display.favouritableTarget
                        if (destination == null) {
                            Text("That is your local time, which is always the first clock.", style = PosterTypography.mono(14.sp, FontWeight.Normal), color = colors.quietInk)
                        } else {
                            ResolvedPlace(state.display, destination, favouritesModel, onDismiss)
                        }
                    }
                    is ConverterDisplayState.Problem -> {
                        Text(state.problem.message, style = PosterTypography.mono(14.sp, FontWeight.Normal), color = colors.accentText)
                        if (state.problem.chips.isNotEmpty()) PromptChipRow(state.problem.chips, model::apply, Modifier.padding(top = 12.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun ResolvedPlace(display: ConverterDisplay, destination: FavouriteDestination, favouritesModel: FavouritesModel, onDismiss: () -> Unit) {
    val colors = LocalPosterColors.current
    val alreadySaved = favouritesModel.isFavourite(destination)
    Column {
        Text(display.targetPlaceName.uppercase(), style = PosterTypography.label(14.sp), color = colors.ink)
        if (display.targetZoneLine.isNotEmpty()) {
            Text(display.targetZoneLine.uppercase(), style = PosterTypography.label(11.sp, tracking = 0.10), color = colors.quietInk, modifier = Modifier.padding(top = 6.dp))
        }
        Text(
            if (alreadySaved) "Already saved" else "Add ${display.targetPlaceName}",
            style = PosterTypography.mono(15.sp),
            color = colors.paper,
            modifier = Modifier
                .padding(top = 16.dp)
                .background(if (alreadySaved) colors.quietInk else colors.accent)
                .clickable(enabled = !alreadySaved, role = Role.Button) {
                    favouritesModel.toggle(destination)
                    onDismiss()
                }
                .padding(horizontal = 18.dp, vertical = 12.dp),
        )
    }
}
