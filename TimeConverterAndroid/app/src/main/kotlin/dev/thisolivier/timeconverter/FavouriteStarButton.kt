package dev.thisolivier.timeconverter

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

/**
 * The star at the far right of the result's time row (item 31/32): outlined,
 * or filled when the target is a favourite; a tap adds it to Clocks or removes
 * it. Port of the iPhone's `FavouriteStarButton`; 48 dp touch target.
 */
@Composable
fun FavouriteStarButton(isFavourite: Boolean, onToggle: () -> Unit, modifier: Modifier = Modifier) {
    IconButton(onClick = onToggle, modifier = modifier) {
        Icon(
            painterResource(if (isFavourite) R.drawable.ic_star_filled else R.drawable.ic_star_outline),
            contentDescription = if (isFavourite) "Remove from Clocks" else "Add to Clocks",
            tint = LocalPosterColors.current.ink,
            modifier = Modifier.size(28.dp),
        )
    }
}
