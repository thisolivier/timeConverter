package dev.thisolivier.timeconverter

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.thisolivier.timeconverter.core.presentation.ReplacementChip

/**
 * The tap-to-replace chips under a prompt (items 7 and 9), drawn as the
 * iPhone draws them: square outlined tickets, mono label, inverting to rust
 * while held. Every chip arrives prepared by the presenter; this decides nothing.
 */
@Composable
fun PromptChipRow(chips: List<ReplacementChip>, onTap: (ReplacementChip) -> Unit, modifier: Modifier = Modifier) {
    FlowRow(
        modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        chips.forEach { chip -> PosterChip(chip.label) { onTap(chip) } }
    }
}

@Composable
private fun PosterChip(label: String, onClick: () -> Unit) {
    val colors = LocalPosterColors.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    Text(
        label,
        style = PosterTypography.mono(15.sp),
        color = if (isPressed) colors.paper else colors.ink,
        modifier = Modifier
            .background(if (isPressed) colors.accent else Color.Transparent)
            .border(1.5.dp, colors.ink)
            .clickable(interactionSource = interactionSource, indication = null, role = Role.Button, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 9.dp),
    )
}
