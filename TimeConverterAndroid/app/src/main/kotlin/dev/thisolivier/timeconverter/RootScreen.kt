package dev.thisolivier.timeconverter

import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource

enum class AppTab { Convert, Saved }

/**
 * The two tabs (item 32, the twin of the iPhone's `RootTabView`): **Convert**,
 * the poster unchanged, and **Saved** (Clocks until item 37; the clock icon
 * stays). A stock `NavigationBar` on the poster paper; the palette's accent
 * marks the selection.
 *
 * The converter's model and the dial's offset live here, so switching tabs
 * keeps the typed text and the dial position. Focus rules:
 * - a "Convert a time" launch (tile, shortcut: [launchRequestCount]) brings
 *   Convert forward, and `ConverterScreen` focuses on the new arrival;
 * - an arrival (return from the background) while Saved is up is marked
 *   handled, so a later switch to Convert never raises the keyboard;
 * - a widget tap ([savedTabRequestCount], item 36b) brings Saved forward and
 *   is likewise marked handled, so the keyboard stays down.
 */
@Composable
fun RootScreen(
    initialInput: String,
    debugLaunchOptions: DebugLaunchOptions,
    favouritesModel: FavouritesModel,
    arrivalCount: Int,
    launchRequestCount: Int,
    savedTabRequestCount: Int = 0,
) {
    val converterModel = remember { ConverterScreenModel(initialInput) }
    var selectedTab by remember {
        mutableStateOf(if (debugLaunchOptions.opensOnSavedTab || savedTabRequestCount > 0) AppTab.Saved else AppTab.Convert)
    }
    var clockOffset by remember { mutableStateOf(ClockOffset.launching(debugLaunchOptions.clockOffsetMinutes)) }
    var handledLaunchRequestCount by remember { mutableIntStateOf(0) }
    var handledSavedTabRequestCount by remember { mutableIntStateOf(0) }

    LaunchedEffect(arrivalCount, launchRequestCount, savedTabRequestCount) {
        if (savedTabRequestCount != handledSavedTabRequestCount) {
            handledSavedTabRequestCount = savedTabRequestCount
            selectedTab = AppTab.Saved
            converterModel.handledArrivalCount = arrivalCount
        } else if (launchRequestCount != handledLaunchRequestCount) {
            handledLaunchRequestCount = launchRequestCount
            selectedTab = AppTab.Convert
        } else if (selectedTab == AppTab.Saved) {
            converterModel.handledArrivalCount = arrivalCount
        }
    }

    val colors = systemPosterColors()
    CompositionLocalProvider(LocalPosterColors provides colors) {
        Scaffold(
            containerColor = colors.paper,
            bottomBar = {
                NavigationBar(containerColor = colors.paper) {
                    val itemColors = NavigationBarItemDefaults.colors(
                        selectedIconColor = colors.accent,
                        selectedTextColor = colors.accent,
                        indicatorColor = colors.accent.copy(alpha = 0.15f),
                        unselectedIconColor = colors.quietInk,
                        unselectedTextColor = colors.quietInk,
                    )
                    NavigationBarItem(
                        selected = selectedTab == AppTab.Convert,
                        onClick = { selectedTab = AppTab.Convert },
                        icon = { Icon(painterResource(R.drawable.ic_tab_convert), contentDescription = null) },
                        label = { Text("Convert") },
                        colors = itemColors,
                    )
                    NavigationBarItem(
                        selected = selectedTab == AppTab.Saved,
                        onClick = { selectedTab = AppTab.Saved },
                        icon = { Icon(painterResource(R.drawable.ic_tab_clocks), contentDescription = null) },
                        label = { Text("Saved") },
                        colors = itemColors,
                    )
                }
            },
        ) { innerPadding ->
            val contentModifier = Modifier.padding(innerPadding).consumeWindowInsets(innerPadding)
            when (selectedTab) {
                AppTab.Convert -> ConverterScreen(converterModel, arrivalCount, favouritesModel, contentModifier)
                AppTab.Saved -> SavedScreen(
                    favouritesModel = favouritesModel,
                    offset = clockOffset,
                    onOffsetChange = { clockOffset = it },
                    arrivalCount = arrivalCount,
                    addPlacePrefill = debugLaunchOptions.addPlaceInput,
                    modifier = contentModifier,
                )
            }
        }
    }
}
