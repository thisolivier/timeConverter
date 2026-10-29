package dev.thisolivier.timeconverter

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.worldclock.WorldClock
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.ZoneId

/**
 * The Clocks tab, the design-free MVP: the local clock first, then one row per
 * favourite, and the readout over the endless dial at the bottom. Port of the
 * iPhone's `ClocksScreen`.
 *
 * Every string comes from `WorldClock.readings`. A coroutine re-reads the
 * clock at each minute boundary (the iPhone's `TimelineView(.everyMinute)`),
 * restarted on every [arrivalCount] so a return from the background is fresh
 * at once; the real time keeps advancing under a non-zero offset. The device
 * zone is read on every tick, so a zone change is picked up.
 */
@Composable
fun ClocksScreen(
    favouritesModel: FavouritesModel,
    offset: ClockOffset,
    onOffsetChange: (ClockOffset) -> Unit,
    arrivalCount: Int,
    modifier: Modifier = Modifier,
) {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(arrivalCount) {
        while (true) {
            now = Instant.now()
            delay(MILLISECONDS_PER_MINUTE - now.toEpochMilli() % MILLISECONDS_PER_MINUTE)
        }
    }

    val display = WorldClock.readings(favouritesModel.favourites, offset.wholeMinutes, now, ZoneId.systemDefault())
    val colors = LocalPosterColors.current
    Column(modifier.fillMaxSize().background(colors.paper)) {
        LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
            item(key = "local") { WorldClockRowView(display.rows.first(), onRemove = null) }
            if (display.rows.size == 1) {
                item(key = "empty") {
                    Text(
                        EMPTY_STATE_COPY,
                        style = PosterTypography.mono(13.sp, FontWeight.Normal),
                        color = colors.quietInk,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                    )
                }
            }
            items(display.rows.drop(1), key = { it.id }) { row ->
                HorizontalDivider(color = colors.quietInk.copy(alpha = 0.3f))
                WorldClockRowView(row, onRemove = row.favourite?.let { favourite -> { favouritesModel.remove(favourite) } })
            }
        }
        HorizontalDivider(color = colors.ink, thickness = 2.dp)
        ClockOffsetControls(display.readout, display.offsetDescription, offset, onOffsetChange)
    }
}

const val EMPTY_STATE_COPY = "Star a destination in Convert and its clock appears here."
private const val MILLISECONDS_PER_MINUTE = 60_000L
