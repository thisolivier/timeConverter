package dev.thisolivier.timeconverter.core.fixtures

import kotlinx.serialization.json.Json
import java.io.File

/**
 * Loads the shared fixture files. The conversion file's path arrives as a
 * system property set by `core/build.gradle.kts` (`timeconverter.fixtures`),
 * with a fallback relative to the module directory for anyone running the
 * tests from an IDE; `world-clock-cases.json` sits beside it.
 */
object SharedFixtures {
    private val json = Json { ignoreUnknownKeys = false }

    fun locate(): File {
        System.getProperty("timeconverter.fixtures")?.let { configured ->
            val file = File(configured)
            if (file.isFile) return file
        }
        val fallback = File("../../fixtures/conversion-cases.json")
        check(fallback.isFile) { "fixtures/conversion-cases.json not found — run scripts/regenerate-fixtures.sh" }
        return fallback
    }

    fun load(file: File = locate()): ConversionCaseFile = json.decodeFromString(file.readText())

    fun locateWorldClock(): File {
        val file = File(locate().absoluteFile.parentFile, "world-clock-cases.json")
        check(file.isFile) { "fixtures/world-clock-cases.json not found — run scripts/regenerate-fixtures.sh" }
        return file
    }

    fun loadWorldClock(file: File = locateWorldClock()): WorldClockCaseFile = json.decodeFromString(file.readText())
}
