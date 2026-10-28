package dev.thisolivier.timeconverter

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon

/**
 * The one "Convert a time" launch, shared by the Quick Settings tile and the
 * launcher shortcut — the Android twin of the iOS Control Center control
 * (backlog 11 / 29): open the app with the field focused and the keyboard up.
 *
 * NEW_TASK | SINGLE_TOP and no CLEAR_* flag: a live activity is brought
 * forward and gets `onNewIntent`, so nothing the user typed is lost.
 * `FOCUS_INPUT_EXTRA` tells `MainActivity` to take focus even when the
 * activity never left the foreground (no `onStart`, e.g. tile tapped over the app).
 */
object ConvertTimeLaunch {
    const val FOCUS_INPUT_EXTRA = "focusInput"
    const val ACTIVITY_FLAGS = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
    const val PENDING_INTENT_FLAGS = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    private const val SHORTCUT_ID = "convert-a-time"

    fun intent(context: Context): Intent =
        Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addFlags(ACTIVITY_FLAGS)
            .putExtra(FOCUS_INPUT_EXTRA, true)

    fun pendingIntent(context: Context): PendingIntent =
        PendingIntent.getActivity(context, 0, intent(context), PENDING_INTENT_FLAGS)

    fun asksForFocus(intent: Intent?): Boolean = intent?.getBooleanExtra(FOCUS_INPUT_EXTRA, false) == true

    /**
     * Long-press on the app icon offers "Convert a time". Dynamic, not a static
     * `shortcuts.xml`: static shortcuts always launch with CLEAR_TASK, which
     * would destroy the activity and the typed text. Idempotent; call on launch.
     */
    fun publishLauncherShortcut(context: Context) {
        val shortcutManager = context.getSystemService(ShortcutManager::class.java) ?: return
        val label = context.getString(R.string.convert_a_time)
        val shortcut = ShortcutInfo.Builder(context, SHORTCUT_ID)
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
            .setIntent(intent(context))
            .build()
        shortcutManager.dynamicShortcuts = listOf(shortcut)
    }
}
