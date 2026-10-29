package dev.thisolivier.timeconverter

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitHorizontalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.horizontalDrag
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.systemGestureExclusion
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.ceil
import kotlin.math.floor

/**
 * The bottom of the Clocks tab: the readout (left) and the signed offset or
 * `Now` (right) over the endless dial. Port of the iPhone's `ClockOffsetControls`.
 */
@Composable
fun ClockOffsetControls(
    readout: String,
    offsetDescription: String?,
    offset: ClockOffset,
    onOffsetChange: (ClockOffset) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = LocalPosterColors.current
    Column(modifier.fillMaxWidth().background(colors.paper).padding(vertical = 12.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.Bottom) {
            Text(readout, style = PosterTypography.mono(16.sp), color = colors.ink, modifier = Modifier.weight(1f))
            Text(offsetDescription ?: "Now", style = PosterTypography.mono(12.sp, FontWeight.Normal), color = colors.quietInk)
        }
        ClockOffsetDial(offset, onOffsetChange, Modifier.padding(top = 8.dp))
    }
}

/**
 * A strip of 15-minute ticks sliding under a fixed accent pointer. A
 * full-width drag is twelve hours, pulling LEFT forwards, and swipes
 * accumulate with no ends ([ClockOffset]); a tap (no drag) resets to now.
 *
 * The strip is a timeline with later times to the right and moves *with* the
 * finger, so a tick sits at `centre + (tickMinutes − centreMinutes) × pointsPerMinute`
 * and pulling the later ticks left under the pointer moves time forwards.
 * Only the ticks inside the frame are drawn, however far out the offset is.
 */
@Composable
fun ClockOffsetDial(offset: ClockOffset, onOffsetChange: (ClockOffset) -> Unit, modifier: Modifier = Modifier) {
    val colors = LocalPosterColors.current
    // The gesture blocks outlive recompositions; read the latest value through these.
    val currentOffset by rememberUpdatedState(offset)
    val currentOnOffsetChange by rememberUpdatedState(onOffsetChange)
    Canvas(
        modifier
            .fillMaxWidth()
            .height(56.dp)
            // A swipe may start at the screen edge; keep the system back gesture off the strip.
            .systemGestureExclusion()
            .semantics { contentDescription = "Shift time. Swipe to move by up to twelve hours, tap to return to now." }
            .pointerInput(Unit) {
                // One gesture: a touch that never passes the slop is the reset tap; otherwise a
                // drag whose translation runs from the touch-down point, slop included (as
                // SwiftUI's `DragGesture.translation` does), so a full-width swipe is twelve hours.
                awaitEachGesture {
                    val down = awaitFirstDown()
                    val pastSlop = awaitHorizontalTouchSlopOrCancellation(down.id) { change, _ -> change.consume() }
                    if (pastSlop == null) {
                        if (currentEvent.changes.none { it.isConsumed }) currentOnOffsetChange(ClockOffset())
                        return@awaitEachGesture
                    }
                    val trackWidth = size.width.toDouble()
                    fun follow(change: PointerInputChange) = currentOnOffsetChange(
                        currentOffset.dragged((change.position.x - down.position.x).toDouble(), trackWidth)
                    )
                    follow(pastSlop)
                    horizontalDrag(pastSlop.id) { change ->
                        change.consume()
                        follow(change)
                    }
                    currentOnOffsetChange(currentOffset.settled())
                }
            },
    ) {
        val pointsPerMinute = size.width / ClockOffset.MINUTES_PER_TRACK_WIDTH
        val centreMinutes = offset.continuousMinutes
        val halfWindowMinutes = ClockOffset.MINUTES_PER_TRACK_WIDTH / 2
        val firstTick = floor((centreMinutes - halfWindowMinutes) / ClockOffset.STEP_MINUTES).toLong()
        val lastTick = ceil((centreMinutes + halfWindowMinutes) / ClockOffset.STEP_MINUTES).toLong()
        val middle = size.height / 2
        for (tick in firstTick..lastTick) {
            val tickMinutes = tick * ClockOffset.STEP_MINUTES.toLong()
            val horizontalPosition = (size.width / 2 + (tickMinutes - centreMinutes) * pointsPerMinute).toFloat()
            val isHour = tickMinutes % 60 == 0L
            val isSixHours = tickMinutes % 360 == 0L
            val tickHeight = (if (isSixHours) 28 else if (isHour) 18 else 9).dp.toPx()
            drawLine(
                color = if (isHour) colors.ink else colors.quietInk,
                start = Offset(horizontalPosition, middle - tickHeight / 2),
                end = Offset(horizontalPosition, middle + tickHeight / 2),
                strokeWidth = (if (isSixHours) 2 else 1).dp.toPx(),
            )
        }
        drawLine(
            color = colors.accent,
            start = Offset(size.width / 2, 0f),
            end = Offset(size.width / 2, size.height),
            strokeWidth = 3.dp.toPx(),
        )
    }
}
