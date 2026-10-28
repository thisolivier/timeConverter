package __APPLICATION_ID__.core

/**
 * Placeholder logic so the two-module wiring is exercised from day one: the
 * app renders this string, the core test pins it, and the release smoke in
 * scripts/ship-android.sh asserts it on the emulator screen (which proves R8
 * kept the code path). Replace it with the real core.
 */
object Greeting {
    fun headline(appName: String): String = "Hello from $appName"
}
