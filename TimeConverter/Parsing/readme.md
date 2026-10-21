# Parsing

Headless implementation of `docs/input-parsing-spec.md`: freeform string in,
either a conversion to run or a prompt to show. No UI, no clock, no
dependencies beyond Foundation.

## Working patterns

- **Nothing reads the clock.** `InputParser.parse(_:now:)` takes the current
  date as a parameter and it travels onward on `ConversionRequest.referenceDate`,
  so `ConversionEngine` is pure too. Tests inject fixed dates and assert exact
  UTC offsets.
- **No `Locale`, no `DateFormatter`.** The spec pins exact output shapes
  (`12:00 pm`, `UTC-5`, `UTC+5:30`), so formatting is hand-rolled in
  `Formatting.swift` and calendars are always `Calendar(identifier: .gregorian)`
  pinned to an explicit zone. A device set to a 24-hour German locale produces
  byte-identical output.
- **Prompts are values.** The parser never formats UI. `Prompt` carries the
  offending token, the side it came from, the raw character range to rewrite and
  the picker rows; the spec's copy lives in `PromptMessages.swift` as a computed
  property so the wording is testable.
- **Resolution order is data.** The five resolvers are an array in
  `ZoneResolverChain.standard`, not a chain of `if`s. Adding a source, or
  swapping the offline gazetteer for a bigger file, touches the array or the
  file — not the resolution logic.
- **Ranges address the raw string, never the normalised one.** Normalisation
  lowercases and collapses whitespace, so normalised offsets do not line up with
  what is in the text field. `NormalizedInput` therefore records, per normalised
  character, the raw offset that produced it, and every zone token leaves the
  tokenizer with a `RawTextRange`. That is what lets a chip rewrite the typed
  sentence in place.
- **Suggestions are a second, separate read of the same tables.** Resolution
  goes through `candidates(for:)` and knows nothing about suggestions;
  `ZoneResolver.vocabulary` is an additive capability with an empty default, so
  the parser stays pure and a resolver that cannot enumerate itself simply never
  contributes a correction.

## Flow

```
NormalizedInput     trim + collapse + lowercase, keeping a per-character map
                    back to the raw string the user typed
  ↓
InputTokenizer      match time at start → split on first standalone in/to →
                    four grammar parts, each zone token with a RawTextRange
                    (or P1/P2/P3)
  ↓
ZoneResolverChain   each zone token through five resolvers in order, stopping
                    at the first with ≥1 candidate → resolved / ambiguous (P4)
                    / unknown (P5); P4 and P5 carry the token's raw range
  ↓
ConversionRequest   time + both resolved zones + the injected reference date
  ↓
ConversionEngine    wall clock → instant (DST policy) → two zone readings,
                    offsets, day-rollover marker, echo line

ZoneSuggestionEngine  (P5 only, off to one side) unknown token → bounded edit
                      distance over ZoneResolver.vocabulary → ≤3 corrections
```

## Components

| File | Purpose |
|---|---|
| `InputParser.swift` | Entry point. `parse(_:now:) -> ParseOutcome`, plus `parseAndConvert` for callers that want the rendered result. |
| `InputTokenizer.swift` | The first-standalone-conjunction split, emitting range-carrying zone tokens. |
| `NormalizedInput.swift` | Normalisation plus the normalised→raw offset map. |
| `RawTextRange.swift` | A character range into the raw input, and `RawTextEditing` to apply one. |
| `TimeTokenParser.swift` | The `<time>` grammar: `H[H]:mm` 24-hour and `H[H][:mm] [space] am/pm`, with lenient spacing and the redundant-meridiem rule. |
| `ParsingModels.swift` | `ParsedTime`, `ZoneCandidate`, `ResolvedZone`, `ConversionRequest`, `ParseOutcome`. |
| `Prompt.swift` | The five prompts as values, plus `ZoneChoice`. |
| `PromptMessages.swift` | The spec's P1–P5 copy. |
| `AbbreviationDisplay.swift` | Expanded zone name + representative cities, for the echo. |
| `ZoneResolver.swift` | The `ZoneResolver` protocol, `ZoneResolution`, and the ordered `ZoneResolverChain`. |
| `ZoneVocabulary.swift` | `ZoneVocabularyEntry` — what a resolver can match, and whether it is a code or a place. |
| `EditDistance.swift` | Bounded Levenshtein. |
| `ZoneSuggestionEngine.swift` | Did-you-mean candidates and the editorial policy that governs them. |
| `AliasZoneResolver.swift` | Step 1 + its table, including each alias's expanded name. |
| `FoundationAbbreviationZoneResolver.swift` | Step 2 + the curated expanded-name table. |
| `TimeZoneDatabaseCityResolver.swift` | Step 3 + the legacy-identifier guard. |
| `CountryZoneResolver.swift`, `CountryZoneTable.swift` | Step 4 + its table. |
| `OfflineFallbackZoneResolver.swift`, `fallback-cities.json` | Step 5 + its bundled data. |
| `WallClockResolver.swift` | Wall-clock time → instant, applying the DST policy explicitly. |
| `ConversionEngine.swift` | `ConversionRequest` → display-ready `ConversionResult`. |
| `Formatting.swift` | Deterministic time, zone-name, UTC-offset and calendar helpers. |

## Decisions worth knowing

- **Canonical country zones.** Step 4 entries are either `.canonical(zone)` —
  the clock on the country's mainland street, so `portugal` → `Europe/Lisbon`
  and never the Azores — or `.noCanonicalClock([zones])` for the six countries
  with no national time (USA, Canada, Australia, Brazil, Russia, Mexico), which
  prompt. Ambiguous *abbreviations* (`CST`, `IST`) always prompt; there is no
  canonical pick for those.
- **Step 3 only indexes area-prefixed identifiers** (`Europe/London`,
  `America/Argentina/Buenos_Aires`) from an allow-list of real IANA areas.
  Depending on OS version the known-identifier list can also carry legacy
  backward names — `Portugal`, `Japan`, `GB`, `US/Pacific`, `Etc/*`. Indexing
  those would let `portugal` resolve as a "city" and bypass the country policy.
- **Echo always names the zone actually used**, derived from the resolved
  identifier rather than the typed token: `porto` echoes as Lisbon. That is what
  makes the canonical-zone and alias choices visible.
- **Abbreviations echo expanded** (spec amendment 2026-10-21). A token resolved
  through step 1 or step 2 carries an `AbbreviationDisplay` — a colloquial name
  and at most two representative cities — so `12pm ET in London` echoes as
  `12:00 pm Eastern Time (New York, Toronto, UTC-5) → 5:00 pm London (UTC+0)`.
  Substituting the bare identifier city would read as though the user had typed
  "New York". Both tables are hand-curated: Foundation has no "what do people
  call this zone" data and deriving a name from the identifier produces "Los
  Angeles Time". The Foundation table is deliberately partial — an abbreviation
  it does not cover falls back to its identifier city, exactly as before.
  **The cities join the offset's parenthetical rather than opening a second
  one**, so the offset's own rendering is untouched and the line avoids
  `Eastern Time (New York, Toronto) (UTC-5)`. Prose that names a place (the DST
  note) and anything tappable (picker rows, chips) keep using the plain city:
  a chip's label has to be a word the user could also type.
- **Did-you-mean policy** (item 9, decided 2026-10-21). Never auto-accept — not
  even a unique distance-1 match, because a silently corrected wrong city
  converts to something that *looks* right. Distance ≤2, tightened to ≤1 for
  tokens of four characters or fewer. **Abbreviation vocabulary is withheld from
  abbreviation-shaped typos unless exactly one candidate survives**: zone codes
  sit one edit from each other (`cst`, `cet`, `ct`, `est`, `mst` are all
  mutually adjacent), so offering one is a coin flip dressed as help — `cst`
  must never offer `cet`. Place names are always offered and outrank codes at
  equal distance. Capped at 3, deduped by token across chain levels.
- **A chip must write a token the chain can read back.** The tables name
  canonical IANA identifiers, but a given OS may ship only the *link* name —
  this one has `Asia/Calcutta`, not `Asia/Kolkata` — which leaves the modern
  city unindexed by step 3 and would turn a tapped P4 chip into a fresh P5. The
  one current case is fixed in the step-5 gazetteer (`kolkata`), and
  `ReplacementChipTests.everyAmbiguityChipWritesATokenTheChainCanResolve` is
  exhaustive over every P4-producing token, so the next one is caught rather
  than shipped.
- **The source reading comes from the resolved instant**, not the requested
  time. On a spring-forward gap the echo therefore shows the shifted time
  (`2:30 am` typed → `3:00 am New York (UTC-4)`), which is how the user sees
  what happened. `ConversionResult.requestedTime` and `.wallClockDisposition`
  keep the original intent available.
- **Time-of-day canonical form is always 12-hour**, even for 24-hour input, per
  the spec's output examples. `23:15` echoes as `11:15 pm`.
- **A redundant meridiem is accepted, a contradictory one is not.** On hours
  outside 1–12 the `am`/`pm` adds nothing, so it is honoured when it agrees
  (`13:00 pm` = 13:00, `18pm` = 18:00, `0:30 am` = 00:30) and rejected as P1
  when it conflicts (`13:00 am`, `0:30 pm`). A contradictory meridiem must fail
  outright rather than fall through to the 24-hour pattern, which would parse
  the time and push the stray `am`/`pm` into the zone token.
- **Regex patterns are computed, not stored.** `Regex` is not `Sendable`, so
  Swift 6 forbids it as static stored state; two tiny patterns are rebuilt per
  parse, which is immeasurable against a keystroke.

## Tests

`TimeConverterTests/` covers the spec's full fixture list — every example
string, each P1–P5 trigger, lenient spacing, `12 am`/`12 pm`, redundant and
contradictory meridiems, CST/IST ambiguity, Porto through the real bundled file
(which is also how resource bundling is verified), both DST-transition branches
and day rollover both ways. On top of that: raw-range mapping through case
folding, collapsed whitespace and emoji (`RawTextRangeTests`); the did-you-mean
suggester including eight typo rows lifted from `docs/qa-input-candidates.md`
§3 and the abbreviation guard (`ZoneSuggestionEngineTests`); and the expanded
echo with its table-integrity checks (`AbbreviationEchoTests`). Run with
`scripts/test.sh --platform all`.

The UI layer that consumes this module is documented in the repo-root
`README.md`.
