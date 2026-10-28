package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ConversionRequest
import dev.thisolivier.timeconverter.core.engine.ZoneDisplayName

/** Which half of the input a zone token came from. Port of Swift `ZoneSide`. */
enum class ZoneSide { Source, Target }

/** The conjunction that split the input. Closed list, per the grammar. Port of Swift `Conjunction`. */
enum class Conjunction(val word: String) {
    In("in"),
    To("to");

    companion object {
        fun fromWord(word: String): Conjunction? = entries.firstOrNull { it.word == word }
    }
}

/**
 * Which resolver in the ordered chain produced a candidate — kept on results so
 * tests can assert *how* a token resolved. Port of Swift `ZoneMatchSource`.
 */
enum class ZoneMatchSource {
    AliasTable,
    FoundationAbbreviation,
    TimeZoneDatabaseCity,
    CountryTable,
    OfflineFallbackList,
    /** Not a resolver: the side the user didn't name, filled from the injected device zone. */
    DeviceLocalZone,
}

/**
 * Editorial display metadata for a zone named by an **abbreviation** (item 13):
 * the colloquial name and at most two cities. Port of Swift `AbbreviationDisplay`.
 */
data class AbbreviationDisplay(val name: String, val representativeCities: List<String>) {
    /** `Eastern Time (New York, Toronto)`. */
    val expandedDescription: String
        get() = if (representativeCities.isEmpty()) name else "$name (${representativeCities.joinToString(", ")})"
}

/** One possible meaning of a zone token, as emitted by a resolver. Port of Swift `ZoneCandidate`. */
data class ZoneCandidate(
    val timeZoneIdentifier: String,
    val matchSource: ZoneMatchSource,
    /** Set only by the two abbreviation resolvers, for abbreviations their curated tables cover. */
    val abbreviationDisplay: AbbreviationDisplay? = null,
) {
    /** `America/New_York` → `New York` — what pickers and chips show, because a chip writes it back. */
    val representativeCityName: String get() = ZoneDisplayName.forIdentifier(timeZoneIdentifier)

    /** Expanded for abbreviations, the plain city otherwise. */
    val echoDisplayName: String get() = abbreviationDisplay?.name ?: representativeCityName
}

/** The only two things parsing can produce. Port of Swift `ParseOutcome`. */
sealed interface ParseOutcome {
    data class Request(val request: ConversionRequest) : ParseOutcome
    data class Prompted(val prompt: Prompt) : ParseOutcome
}

/**
 * Renders the typed (lowercased) token back as a label. Port of Swift
 * `ZoneTokenDisplay`: a code is all caps, a multi-word colloquialism is title
 * case (`East Coast`), because `EAST COAST` in a sentence reads as shouting.
 */
object ZoneTokenDisplay {
    fun label(token: String): String {
        if (!token.contains(' ')) return token.uppercase()
        return token.split(' ').joinToString(" ") { FoundationCapitalization.capitalized(it) }
    }
}

/**
 * Port of Foundation's `String.capitalized` for the tokens this app shows:
 * every letter that starts a word is uppercased and every other letter
 * lowercased. A word starts after anything that is not a letter, a combining
 * mark or an apostrophe — so `port-au-prince` → `Port-Au-Prince`, `u.s.` →
 * `U.S.`, `o'higgins` → `O'higgins`, exactly as Foundation renders them.
 */
object FoundationCapitalization {
    fun capitalized(text: String): String {
        val builder = StringBuilder(text.length)
        var previousContinuesWord = false
        var index = 0
        while (index < text.length) {
            val codePoint = text.codePointAt(index)
            val piece = String(Character.toChars(codePoint))
            val isLetter = Character.isLetter(codePoint)
            builder.append(
                when {
                    !isLetter -> piece
                    previousContinuesWord -> piece.lowercase()
                    else -> piece.uppercase()
                }
            )
            val type = Character.getType(codePoint)
            previousContinuesWord = isLetter ||
                type == Character.NON_SPACING_MARK.toInt() ||
                type == Character.COMBINING_SPACING_MARK.toInt() ||
                piece == "'" || piece == "’"
            index += Character.charCount(codePoint)
        }
        return builder.toString()
    }
}
