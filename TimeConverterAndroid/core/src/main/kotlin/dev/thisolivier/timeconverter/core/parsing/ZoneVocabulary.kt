package dev.thisolivier.timeconverter.core.parsing

/**
 * One token a resolver can match, exposed so the did-you-mean suggester can
 * measure edit distances against it. Port of Swift `ZoneVocabularyEntry`.
 */
data class ZoneVocabularyEntry(
    /** The exact normalised token a user could type to hit this entry. */
    val token: String,
    val shape: Shape,
    /** Which resolver owns it; doubles as the chain-level tie-break. */
    val matchSource: ZoneMatchSource,
) {
    enum class Shape {
        /** A zone code (`et`, `cst`) — short, opaque, and mutually one edit apart. */
        Abbreviation,
        /** A city or country name (`london`, `new york`). */
        PlaceName,
    }

    /** Chip-facing form: `PST` for a code, `New York` for a place (Foundation's `capitalized`). */
    val suggestionLabel: String
        get() = when (shape) {
            Shape.Abbreviation -> token.uppercase()
            Shape.PlaceName -> FoundationCapitalization.capitalized(token)
        }
}
