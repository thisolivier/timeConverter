package dev.thisolivier.timeconverter

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination
import dev.thisolivier.timeconverter.core.worldclock.SavedGridLayout
import dev.thisolivier.timeconverter.core.worldclock.WorldClock
import dev.thisolivier.timeconverter.core.worldclock.WorldClockDisplay
import dev.thisolivier.timeconverter.core.worldclock.WorldClockRow
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.ZoneId

/**
 * The Saved tab (item 32 as Clocks; item 37 brings the 2026-11-04 design):
 * the local clock and every saved place as a grid whose shape follows the
 * count — one column up to three clocks, two up to eight, three beyond —
 * the readout over the endless dial at the bottom, and a floating `+` for
 * adding a place by name. Port of the iPhone's `SavedScreen`.
 *
 * Every string comes from `WorldClock.readings`; the column decision is
 * `SavedGridLayout` in `:core`. A coroutine re-reads the clock at each minute
 * boundary, restarted on every [arrivalCount]. Tapping a saved cell asks
 * before removing it; the local cell is inert.
 */
@Composable
fun SavedScreen(
    favouritesModel: FavouritesModel,
    offset: ClockOffset,
    onOffsetChange: (ClockOffset) -> Unit,
    arrivalCount: Int,
    addPlacePrefill: String?,
    modifier: Modifier = Modifier,
) {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(arrivalCount) {
        while (true) {
            now = Instant.now()
            delay(MILLISECONDS_PER_MINUTE - now.toEpochMilli() % MILLISECONDS_PER_MINUTE)
        }
    }
    var favouriteToRemove by remember { mutableStateOf<FavouriteDestination?>(null) }
    var isAddingAPlace by remember { mutableStateOf(addPlacePrefill != null) }

    val display = WorldClock.readings(favouritesModel.favourites, offset.wholeMinutes, now, ZoneId.systemDefault())
    val colors = LocalPosterColors.current
    Column(modifier.fillMaxSize().background(colors.paper)) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            SavedGrid(display, onTapFavourite = { favouriteToRemove = it }, Modifier.fillMaxSize().verticalScroll(rememberScrollState()))
            AddPlaceButton(onClick = { isAddingAPlace = true }, Modifier.align(Alignment.BottomEnd).padding(end = 20.dp, bottom = 16.dp))
        }
        HorizontalDivider(color = colors.ink, thickness = 2.dp)
        ClockOffsetControls(display.readout, display.offsetDescription, offset, onOffsetChange)
    }

    favouriteToRemove?.let { favourite ->
        AlertDialog(
            onDismissRequest = { favouriteToRemove = null },
            containerColor = colors.paper,
            titleContentColor = colors.ink,
            title = { Text("Remove ${favourite.label.placeNameDescription} from Saved?", style = PosterTypography.mono(16.sp)) },
            confirmButton = {
                TextButton(onClick = { favouritesModel.remove(favourite); favouriteToRemove = null }) {
                    Text("Remove", color = colors.accentText, style = PosterTypography.mono(15.sp))
                }
            },
            dismissButton = {
                TextButton(onClick = { favouriteToRemove = null }) { Text("Cancel", color = colors.ink, style = PosterTypography.mono(15.sp)) }
            },
        )
    }
    if (isAddingAPlace) {
        AddSavedPlaceSheet(favouritesModel, initialText = addPlacePrefill.orEmpty(), onDismiss = { isAddingAPlace = false })
    }
}

/** The clocks in reading order, hairlines between cells, a short last row kept at column width. */
@Composable
private fun SavedGrid(display: WorldClockDisplay, onTapFavourite: (FavouriteDestination) -> Unit, modifier: Modifier = Modifier) {
    val columnCount = SavedGridLayout.columnCount(display.rows.size)
    val density = SavedCellDensity(columnCount)
    val rows = SavedGridLayout.rows(display.rows, columnCount)
    val colors = LocalPosterColors.current
    val hairline = colors.ink.copy(alpha = 0.6f)
    Column(modifier.padding(top = 12.dp, bottom = 72.dp)) {
        rows.forEachIndexed { rowIndex, row ->
            if (rowIndex > 0) HorizontalDivider(color = hairline, thickness = 1.dp)
            Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
                row.forEachIndexed { cellIndex, clock ->
                    if (cellIndex > 0) Box(Modifier.width(1.dp).fillMaxHeight().background(hairline))
                    SavedCell(clock, density, onTapFavourite, Modifier.weight(1f))
                }
                repeat(columnCount - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        if (display.rows.size == 1) {
            Text(
                SAVED_EMPTY_STATE_COPY,
                style = PosterTypography.mono(13.sp, FontWeight.Normal),
                color = colors.quietInk,
                modifier = Modifier.padding(horizontal = density.horizontalPadding, vertical = 8.dp),
            )
        }
    }
}

@Composable
private fun SavedCell(clock: WorldClockRow, density: SavedCellDensity, onTapFavourite: (FavouriteDestination) -> Unit, modifier: Modifier) {
    val favourite = clock.favourite
    val tappable = if (favourite == null) Modifier else Modifier.clickable(role = Role.Button, onClickLabel = "Remove from Saved") { onTapFavourite(favourite) }
    SavedClockCell(clock, density, modifier.then(tappable))
}

/** The floating `+`: a light disc with a rust plus, over the grid's bottom-right corner. */
@Composable
private fun AddPlaceButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = LocalPosterColors.current
    val disc = Color.White.copy(alpha = if (colors === PosterColors.dark) 0.12f else 0.45f).compositeOver(colors.paper)
    Box(
        modifier
            .shadow(8.dp, CircleShape)
            .background(disc, CircleShape)
            .size(56.dp)
            .clickable(role = Role.Button, onClickLabel = "Add a place", onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(painterResource(R.drawable.ic_add_place), contentDescription = "Add a place", tint = colors.accent, modifier = Modifier.size(26.dp))
    }
}

const val SAVED_EMPTY_STATE_COPY = "Tap + to save a place, or star a result in Convert."
private const val MILLISECONDS_PER_MINUTE = 60_000L
