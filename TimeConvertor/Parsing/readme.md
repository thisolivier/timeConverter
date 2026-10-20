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
  offending token, the side it came from and the picker rows; the spec's copy
  lives in `PromptMessages.swift` as a computed property so the wording is
  testable.
- **Resolution order is data.** The five resolvers are an array in
  `ZoneResolverChain.standard`, not a chain of `if`s. Adding a source, or
  swapping the offline gazetteer for a bigger file, touches the array or the
  file — not the resolution logic.

## Flow

```
InputTokenizer      normalise → match time at start → split on first
                    standalone in/to → four grammar parts (or P1/P2/P3)
  ↓
ZoneResolverChain   each zone token through five resolvers in order, stopping
                    at the first with ≥1 candidate → resolved / ambiguous (P4)
                    / unknown (P5)
  ↓
ConversionRequest   time + both resolved zones + the injected reference date
  ↓
ConversionEngine    wall clock → instant (DST policy) → two zone readings,
                    offsets, day-rollover marker, echo line
```

## Components

| File | Purpose |
|---|---|
| `InputParser.swift` | Entry point. `parse(_:now:) -> ParseOutcome`, plus `parseAndConvert` for callers that want the rendered result. |
| `InputTokenizer.swift` | Normalisation and the first-standalone-conjunction split. |
| `TimeTokenParser.swift` | The `<time>` grammar: `H[H]:mm` 24-hour and `H[H][:mm] [space] am/pm`, with lenient spacing and the redundant-meridiem rule. |
| `ParsingModels.swift` | `ParsedTime`, `ZoneCandidate`, `ResolvedZone`, `ConversionRequest`, `ParseOutcome`, `Prompt`, `ZoneChoice`. |
| `PromptMessages.swift` | The spec's P1–P5 copy. |
| `ZoneResolver.swift` | The `ZoneResolver` protocol, `ZoneResolution`, and the ordered `ZoneResolverChain`. |
| `AliasZoneResolver.swift` | Step 1 + its table. |
| `FoundationAbbreviationZoneResolver.swift` | Step 2. |
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
  identifier rather than the typed token: `porto` echoes as Lisbon, `et` as New
  York. That is what makes the canonical-zone and alias choices visible.
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

`TimeConvertorTests/` covers the spec's full fixture list — every example
string, each P1–P5 trigger, lenient spacing, `12 am`/`12 pm`, redundant and
contradictory meridiems, CST/IST ambiguity, Porto through the real bundled file
(which is also how resource bundling is verified), both DST-transition branches
and day rollover both ways. Run with `scripts/test.sh --platform all`.

The UI layer that consumes this module is documented in the repo-root
`README.md`.
