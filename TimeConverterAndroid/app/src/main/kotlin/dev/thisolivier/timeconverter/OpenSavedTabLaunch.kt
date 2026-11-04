package dev.thisolivier.timeconverter

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * The saved-cities widget's tap (item 36b): open the app on the Saved tab —
 * not the converter, and without touching the typed text or raising the
 * keyboard (Olivier, 2026-11-04). The Android twin of iOS's
 * `timeconverter://saved`. Same flags as `ConvertTimeLaunch`, so a live
 * activity is brought forward and gets `onNewIntent` rather than being
 * recreated.
 */
object OpenSavedTabLaunch {
    const val OPEN_SAVED_TAB_EXTRA = "openSavedTab"

    fun intent(context: Context): Intent =
        Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addFlags(ConvertTimeLaunch.ACTIVITY_FLAGS)
            .putExtra(OPEN_SAVED_TAB_EXTRA, true)

    fun pendingIntent(context: Context): PendingIntent =
        PendingIntent.getActivity(context, 1, intent(context), ConvertTimeLaunch.PENDING_INTENT_FLAGS)

    fun asksForSavedTab(intent: Intent?): Boolean = intent?.getBooleanExtra(OPEN_SAVED_TAB_EXTRA, false) == true
}
