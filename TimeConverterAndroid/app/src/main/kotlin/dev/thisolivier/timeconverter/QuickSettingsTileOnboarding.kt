package dev.thisolivier.timeconverter

import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build

/**
 * One-time offer to add the "Convert a time" tile (API 33+
 * `StatusBarManager.requestAddTileService`). Asked once per install, whatever
 * the answer: the flag is written before asking. Below 33 there is no API;
 * the readme documents the manual path (edit Quick Settings, drag the tile in).
 *
 * Scripted launches (the `initialInput` extra: `run-android.sh --input`, the
 * ship smoke) skip it without spending the one ask, so a fresh install's
 * screenshot is the app, not a system dialog.
 */
object QuickSettingsTileOnboarding {
    private const val PREFERENCES_NAME = "quick-settings-tile"
    private const val ALREADY_OFFERED_KEY = "addTileOffered"

    fun shouldOffer(sdkVersion: Int, alreadyOffered: Boolean, isScriptedLaunch: Boolean): Boolean =
        sdkVersion >= Build.VERSION_CODES.TIRAMISU && !alreadyOffered && !isScriptedLaunch

    /** `onAnswered` runs on the main thread once the dialog is gone (any outcome). */
    fun offerOnce(activity: Activity, isScriptedLaunch: Boolean, onAnswered: () -> Unit) {
        val preferences = activity.getSharedPreferences(PREFERENCES_NAME, Activity.MODE_PRIVATE)
        val alreadyOffered = preferences.getBoolean(ALREADY_OFFERED_KEY, false)
        if (!shouldOffer(Build.VERSION.SDK_INT, alreadyOffered, isScriptedLaunch)) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        preferences.edit().putBoolean(ALREADY_OFFERED_KEY, true).apply()
        val statusBarManager = activity.getSystemService(StatusBarManager::class.java) ?: return
        statusBarManager.requestAddTileService(
            ComponentName(activity, ConvertTimeTileService::class.java),
            activity.getString(R.string.convert_a_time),
            Icon.createWithResource(activity, R.drawable.ic_tile_convert_time),
            activity.mainExecutor,
        ) { _ -> onAnswered() }
    }
}
