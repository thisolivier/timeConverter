package dev.thisolivier.timeconverter

import android.annotation.SuppressLint
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * The Quick Settings tile "Convert a time": a launcher, not a toggle. Always
 * ACTIVE; a tap collapses the shade and opens the app ready to type
 * (`ConvertTimeLaunch`). On the lock screen the unlock comes first, as with
 * the iOS control: on API 34+ SystemUI does that itself for the PendingIntent
 * (wrapping it in our own `unlockAndRun` as well made SystemUI ask twice and
 * drop the launch — seen on the API 36 emulator); below 34 we ask.
 *
 * Not in active mode (no `ACTIVE_TILE` meta-data): the system binds it each
 * time the shade opens, so `onStartListening` re-asserts ACTIVE and the tile
 * never shows the default unavailable/inactive look. It does no work, so the
 * binding is cheap.
 */
class ConvertTimeTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        tile.state = Tile.STATE_ACTIVE
        tile.label = getString(R.string.convert_a_time)
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // API 34+: the Intent overload throws for apps targeting 34+.
            startActivityAndCollapse(ConvertTimeLaunch.pendingIntent(this))
        } else if (isLocked) {
            unlockAndRun { startActivityAndCollapseBelowApi34() }
        } else {
            startActivityAndCollapseBelowApi34()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun startActivityAndCollapseBelowApi34() {
        @Suppress("DEPRECATION")
        startActivityAndCollapse(ConvertTimeLaunch.intent(this))
    }
}
