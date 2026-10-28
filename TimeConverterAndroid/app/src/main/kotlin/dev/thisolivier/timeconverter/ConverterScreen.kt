package dev.thisolivier.timeconverter

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.presentation.PosterLayoutMode
import kotlin.math.abs

/**
 * The poster, as the iPhone lays it out: title, rule, labelled input box with
 * the source echo inside it, the rule-and-arrow band, then the result.
 *
 * Owns only platform state: focus, the IME, the typed text (via the model).
 * Item 19's choreography: the *decision* is `PosterLayoutMode` in `:core`; the
 * IME observation and the animation live here. `arrivalCount` ticks on every
 * launch and return from the background — focus is taken then, never
 * mid-session (the iOS `InputFocusPolicy`).
 */
@Composable
fun ConverterScreen(initialInput: String, arrivalCount: Int) {
    val model = remember { ConverterScreenModel(initialInput) }
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current

    LaunchedEffect(arrivalCount) {
        focusRequester.requestFocus()
        keyboardController?.show()
    }

    val keyboardIsVisible = WindowInsets.ime.getBottom(LocalDensity.current) > 0
    val layoutMode = PosterLayoutMode.mode(model.input, keyboardIsVisible)

    val dismissKeyboard by rememberUpdatedState {
        focusManager.clearFocus()
        keyboardController?.hide()
    }
    // A drag anywhere puts the keyboard away, whether or not the content can scroll.
    val dismissOnDrag = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                if (source == NestedScrollSource.UserInput && abs(available.y) > 2f) dismissKeyboard()
                return Offset.Zero
            }
        }
    }

    val colors = systemPosterColors()
    CompositionLocalProvider(LocalPosterColors provides colors) {
        Box(
            Modifier
                .fillMaxSize()
                .background(colors.paper)
                .nestedScroll(dismissOnDrag)
                // Sees only taps the field and the chips declined.
                .pointerInput(Unit) { detectTapGestures { dismissKeyboard() } },
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(
                Modifier
                    .safeDrawingPadding()
                    .verticalScroll(rememberScrollState())
                    .widthIn(max = 430.dp)
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp)
                    .padding(top = animateDpAsState(if (layoutMode.showsTitleBlock) 40.dp else 16.dp, tween(240)).value, bottom = 40.dp)
            ) {
                AnimatedVisibility(
                    visible = layoutMode.showsTitleBlock,
                    enter = fadeIn(tween(220, delayMillis = 40)) + expandVertically(tween(240)),
                    exit = fadeOut(tween(120)) + shrinkVertically(tween(240)),
                ) {
                    Column(Modifier.padding(bottom = 20.dp)) {
                        TitleBlock()
                        PosterRule(Modifier.padding(top = 22.dp))
                    }
                }

                Text("TIME & PLACES", style = PosterTypography.label(12.sp), color = colors.ink)

                ConverterInputBox(
                    fieldValue = model.fieldValue,
                    sourceEchoLine = model.displayState.convertedDisplay?.sourceEchoLine,
                    focusRequester = focusRequester,
                    onFieldValueChange = model::onFieldValueChange,
                    onSubmit = model::showWithoutWaiting,
                    modifier = Modifier.padding(top = 10.dp),
                )

                PosterArrowSeparator(Modifier.padding(top = if (layoutMode.showsTitleBlock) 26.dp else 18.dp))

                PosterResultSection(
                    displayState = model.displayState,
                    layoutMode = layoutMode,
                    onChipTap = model::apply,
                    modifier = Modifier.padding(top = if (layoutMode.showsTitleBlock) 22.dp else 16.dp),
                )
            }
        }
    }
}

/**
 * `TIME` over `CONVERTER`, stacked tighter than the font's own line box, both
 * at one size: the largest (76sp down to 38sp, 2sp steps) at which the wider
 * word fits the column — the Swift title's shared size with `minimumScaleFactor`.
 */
@Composable
private fun TitleBlock() {
    val baseStyle = PosterTypography.display(76.sp).copy(color = LocalPosterColors.current.ink)
    val textMeasurer = rememberTextMeasurer()
    BoxWithConstraints {
        val availableWidth = constraints.maxWidth
        val titleSize = remember(availableWidth, baseStyle) {
            (76 downTo 38 step 2).firstOrNull { candidateSize ->
                val measured = textMeasurer.measure("CONVERTER", baseStyle.copy(fontSize = candidateSize.sp), maxLines = 1, softWrap = false)
                measured.size.width <= availableWidth
            } ?: 38
        }
        val titleStyle = baseStyle.copy(fontSize = titleSize.sp)
        Column {
            BasicText("TIME", style = titleStyle, maxLines = 1, modifier = Modifier.trimmedVertically(10.dp))
            BasicText("CONVERTER", style = titleStyle, maxLines = 1, modifier = Modifier.trimmedVertically(10.dp))
        }
    }
}

/**
 * Lays the content out `trim` shorter at top and bottom — the Compose twin of
 * the Swift title's negative stack spacing, which the font's own line box
 * (ascender and descender room caps never use) would otherwise forbid.
 */
private fun Modifier.trimmedVertically(trim: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val trimPixels = trim.roundToPx()
    layout(placeable.width, (placeable.height - 2 * trimPixels).coerceAtLeast(0)) {
        placeable.place(0, -trimPixels)
    }
}
