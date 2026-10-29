package dev.thisolivier.timeconverter

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.worldclock.WorldClockRow

/**
 * One clock: the `WorldClockRow` strings in the poster's fonts at a modest
 * size. Logic-free, like `PosterResultSection`. A favourite row ends in a
 * remove button — the MVP's stand-in for the iPhone's swipe-to-delete.
 */
@Composable
fun WorldClockRowView(row: WorldClockRow, onRemove: (() -> Unit)?, modifier: Modifier = Modifier) {
    val colors = LocalPosterColors.current
    Row(modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(row.placeName.uppercase(), style = PosterTypography.label(12.sp), color = colors.ink)
            // Digits and meridiem in one text, so they share a baseline.
            Text(
                buildAnnotatedString {
                    append(row.clockDigits)
                    withStyle(SpanStyle(fontSize = 16.sp)) { append(" ${row.meridiem}") }
                },
                style = PosterTypography.display(44.sp),
                color = colors.ink,
                modifier = Modifier.padding(top = 2.dp),
            )
            if (row.zoneLine.isNotEmpty()) {
                Text(row.zoneLine.uppercase(), style = PosterTypography.label(10.sp, tracking = 0.10), color = colors.ink)
            }
            if (row.offsetPhrase.isNotEmpty()) {
                Text(row.offsetPhrase, style = PosterTypography.mono(12.sp, FontWeight.Normal), color = colors.quietInk)
            }
        }
        if (onRemove != null) {
            IconButton(onClick = onRemove) {
                Icon(
                    painterResource(R.drawable.ic_remove_clock),
                    contentDescription = "Remove ${row.placeName} from Clocks",
                    tint = colors.quietInk,
                )
            }
        }
    }
}
