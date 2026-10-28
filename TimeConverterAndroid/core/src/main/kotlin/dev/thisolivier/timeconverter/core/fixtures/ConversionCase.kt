package dev.thisolivier.timeconverter.core.fixtures

import kotlinx.serialization.Serializable

/**
 * The cross-platform fixture schema — one case of `fixtures/conversion-cases.json`
 * at the repository root. The Swift side GENERATES this file from its own core
 * (`scripts/regenerate-fixtures.sh`); both sides then assert against it. Any
 * field here must stay in step with Swift `SharedFixtureModels.swift`.
 */
@Serializable
data class ConversionCaseFile(
    val schemaVersion: Int,
    val generatedBy: String,
    val cases: List<ConversionCase>,
)

@Serializable
data class ConversionCase(
    val id: String,
    val input: String,
    /** ISO-8601 instant injected as "now". */
    val now: String,
    /** IANA identifier injected as the device zone. */
    val localZone: String,
    val note: String? = null,
    val expected: ExpectedOutcome,
)

@Serializable
data class ExpectedOutcome(
    /** `conversion`, `prompt` or `hint`. */
    val kind: String,
    val sourceZone: String? = null,
    val targetZone: String? = null,
    /** `HH:mm`, the time as typed (before any DST shift). */
    val requestedTime: String? = null,
    val dayOffset: Int? = null,
    val display: ExpectedDisplay? = null,
    val promptId: String? = null,
    val message: String? = null,
    val chips: List<ExpectedChip> = emptyList(),
)

/**
 * Mirrors Swift `ConverterDisplay` field for field. Every field is compared
 * exactly: the generic zone name in `sourceZoneLine` / `targetZoneLine` comes
 * from the shared iOS-origin snapshot `zone-names.json` on all platforms.
 */
@Serializable
data class ExpectedDisplay(
    val echoLine: String,
    val detailLine: String,
    val sourceEchoLine: String,
    val sourcePlaceName: String,
    val sourceClockDigits: String,
    val sourceMeridiem: String,
    val sourceZoneLine: String,
    val targetPlaceLabel: String,
    val targetPlaceName: String,
    val targetClockDigits: String,
    val targetMeridiem: String,
    val targetZoneLine: String,
    val footerSentence: String,
    val offsetPhrase: String,
    val daylightSavingNote: String? = null,
)

@Serializable
data class ExpectedChip(
    val label: String,
    val replacementText: String,
    val replacementStart: Int,
    val replacementEnd: Int,
)
