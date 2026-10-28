package dev.thisolivier.timeconverter

import android.app.PendingIntent
import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What a JVM test can see of the tile/shortcut launch without Robolectric:
 * the flag sets (compile-time constants) and the onboarding decision.
 */
class ConvertTimeLaunchTests {

    @Test
    fun launchStartsANewTaskButReusesALiveActivity() {
        val flags = ConvertTimeLaunch.ACTIVITY_FLAGS
        assertEquals(Intent.FLAG_ACTIVITY_NEW_TASK, flags and Intent.FLAG_ACTIVITY_NEW_TASK)
        assertEquals(Intent.FLAG_ACTIVITY_SINGLE_TOP, flags and Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    @Test
    fun launchNeverClearsTheTaskOrTheTypedText() {
        val flags = ConvertTimeLaunch.ACTIVITY_FLAGS
        assertEquals(0, flags and Intent.FLAG_ACTIVITY_CLEAR_TASK)
        assertEquals(0, flags and Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }

    @Test
    fun pendingIntentIsImmutable() {
        val flags = ConvertTimeLaunch.PENDING_INTENT_FLAGS
        assertEquals(PendingIntent.FLAG_IMMUTABLE, flags and PendingIntent.FLAG_IMMUTABLE)
        assertEquals(0, flags and PendingIntent.FLAG_MUTABLE)
    }

    @Test
    fun focusExtraKeyIsStable() {
        assertEquals("focusInput", ConvertTimeLaunch.FOCUS_INPUT_EXTRA)
    }

    @Test
    fun onboardingAsksOnceOnApi33AndUp() {
        assertTrue(QuickSettingsTileOnboarding.shouldOffer(sdkVersion = 33, alreadyOffered = false, isScriptedLaunch = false))
        assertTrue(QuickSettingsTileOnboarding.shouldOffer(sdkVersion = 36, alreadyOffered = false, isScriptedLaunch = false))
        assertFalse(QuickSettingsTileOnboarding.shouldOffer(sdkVersion = 36, alreadyOffered = true, isScriptedLaunch = false))
    }

    @Test
    fun onboardingNeverAsksBelowApi33() {
        assertFalse(QuickSettingsTileOnboarding.shouldOffer(sdkVersion = 32, alreadyOffered = false, isScriptedLaunch = false))
        assertFalse(QuickSettingsTileOnboarding.shouldOffer(sdkVersion = 26, alreadyOffered = false, isScriptedLaunch = false))
    }

    @Test
    fun scriptedLaunchesSkipTheDialog() {
        assertFalse(QuickSettingsTileOnboarding.shouldOffer(sdkVersion = 36, alreadyOffered = false, isScriptedLaunch = true))
    }
}
