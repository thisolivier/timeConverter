package dev.thisolivier.timeconverter.core.fixtures

import kotlin.test.Ignore
import kotlin.test.Test

/**
 * The parser half of the shared contract — every fixture, end to end, from the
 * typed string to the full display or prompt. Ignored until the parser port
 * lands (backlog item 24b); the engine half runs today.
 */
class SharedFixtureParserTests {
    @Ignore("parser port pending — see TimeConverterAndroid/readme.md")
    @Test
    fun `parser agrees with every fixture end to end`() {
    }
}
