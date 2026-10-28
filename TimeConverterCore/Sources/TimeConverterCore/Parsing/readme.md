# Parsing

Headless implementation of `docs/input-parsing-spec.md`: freeform string in,
either a conversion to run or a prompt to show. No UI, no clock, no
dependencies beyond Foundation.

Part of the `TimeConverterCore` package — see the package readme one level up
for the public surface and how the two app shells consume it. Everything in
this directory is `internal` to the package: the shells never see a `Prompt` or
an `InputParser`, only the rendered values the presenter hands them.

## Working patterns

- **Nothing reads the clock, and nothing reads the device zone.**
  `InputParser.parse(_:now:localZone:)` takes both as parameters; the date
  travels onward on `ConversionRequest.referenceDate`, so `ConversionEngine` is
  pure too, and the zone is used to fill in a side the user didn't name — and,
  since item 22, to read the current wall clock a bare-zone input converts.
  `TimeZone.current` is read in exactly two places in the whole repo — next to
  `Date()` in `ContentView` (iOS) and `MenuBarConverterView` (macOS). Tests
  inject fixed dates and fixed zones (`FixedZones`) and assert exact UTC
  offsets.
- **No `DateFormatter`, and only one pinned `Locale`.** The spec pins exact
  output shapes (`12:00 pm`, `UTC-5`, `UTC+5:30`), so formatting is hand-rolled
  in `Formatting.swift` and calendars are always
  `Calendar(identifier: .gregorian)` pinned to an explicit zone. A device set to
  a 24-hour German locale produces byte-identical output. The one exception is
  item 21's zone name, which comes from `TimeZone.localizedName` because naming
  443 zones by hand is not an editorial decision worth making — and it is read
  through `ZoneNameFormatting.locale`, a hard-pinned `en_US`, so the rule still
  holds: output does not vary by device.
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
                    time + up to two zone tokens, each with a RawTextRange.
                    One side may legitimately be empty (or P1/P2). No time at
                    all → the whole input is one target-side token and the time
                    is nil ("ET" = now), or P1 if it cannot be a token.
                    A leading `now` is a time with nil value (item 23)
  ↓
ZoneResolverChain   each *named* zone token through five resolvers in order,
                    stopping at the first with ≥1 candidate → resolved /
                    ambiguous (P4) / unknown (P5); P4 and P5 carry the token's
                    raw range. An unnamed side becomes the injected local zone
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
| `InputParser.swift` | Entry point. `parse(_:now:localZone:) -> ParseOutcome`, plus `parseAndConvert` for callers that want the rendered result. Also the one place local defaulting happens, and the one place a bare-zone input's missing time becomes the current clock. |
| `InputTokenizer.swift` | The first-standalone-conjunction split, emitting range-carrying zone tokens — either side may be empty, and so may the time (`bareZoneTokens`, item 22). |
| `NormalizedInput.swift` | Normalisation plus the normalised→raw offset map. |
| `RawTextRange.swift` | A character range into the raw input, and `RawTextEditing` to apply one. |
| `TimeTokenParser.swift` | The `<time>` grammar: `H[H]:mm` 24-hour (colon optional — `1500`, `930`, item 27) and `H[H][[:]mm] [space] am/pm`, with lenient spacing and the redundant-meridiem rule. |
| `ParsingModels.swift` | `ParsedTime`, `ZoneCandidate`, `ResolvedZone`, `ConversionRequest`, `ParseOutcome`. |
| `Prompt.swift` | The prompts as values (P1, P2, P4, P5 — P3 is retired), plus `ZoneChoice`. |
| `PromptMessages.swift` | The spec's prompt copy. |
| `AbbreviationDisplay.swift` | Expanded zone name + representative cities, for the echo. |
| `ZoneLabel.swift` | How the result band names a zone (item 21): `.place` or `.abbreviation(code:expandedName:)`, plus the re-casing that turns a lowercased `et` back into `ET`. |
| `ZoneRepresentativeCities.swift` | Which two or three cities stand for a zone — the two abbreviation tables read backwards, with the self-consistency rule that rejects their loose ends. |
| `ZoneResolver.swift` | The `ZoneResolver` protocol, `ZoneResolution`, and the ordered `ZoneResolverChain`. |
| `ZoneVocabulary.swift` | `ZoneVocabularyEntry` — what a resolver can match, and whether it is a code or a place. |
| `EditDistance.swift` | Bounded Levenshtein. |
| `ZoneSuggestionEngine.swift` | Did-you-mean candidates and the editorial policy that governs them. |
| `AliasZoneResolver.swift` | Step 1 + its table, including each alias's expanded name. |
| `FoundationAbbreviationZoneResolver.swift` | Step 2 + the curated expanded-name table. |
| `TimeZoneDatabaseCityResolver.swift` | Step 3 + the legacy-identifier guard. |
| `CountryZoneResolver.swift`, `CountryZoneTable.swift` | Step 4 + its table. |
| `OfflineFallbackZoneResolver.swift`, `../Resources/fallback-cities.json` | Step 5 + its bundled data, reached through `Bundle.module`. |
| `WallClockResolver.swift` | Wall-clock time → instant, applying the DST policy explicitly. |
| `ConversionEngine.swift` | `ConversionRequest` → display-ready `ConversionResult`. |
| `Formatting.swift` | Deterministic time, zone-name, UTC-offset and calendar helpers. |

## Decisions worth knowing

- **One named zone is enough; the conjunction decides which side it is** (spec
  amendment 2026-10-22, item 14, reversing the original reject-on-one-zone
  rule). `7pm in London` → London is the **target** and the source defaults to
  the device zone; `7pm east coast` → East Coast is the **source** and the
  target defaults. A dangling conjunction is read the same way: a zone *before*
  it (`7pm tokyo in`) is still a named source, because the conjunction's only
  job is to say which side the named zone is on. Only a time with no zone on
  either side (`7pm`, `7pm in`) prompts, and that prompt is **P2**, reworded;
  **P3 is retired** and no `Prompt` case reports it.
- **A bare zone token means "now, over there"** (spec amendment 2026-10-23,
  item 22). `ET`, `Tokyo`, `east coast` with no time at all converts the
  **current device clock** — hours *and* minutes — into the named zone: the
  time is `ParsedTime.wallClock(of: now, in: localZone)`, the source is the
  device zone (so the echo carries the same `(local)` marker item 14 added) and
  the target is the named token. Nothing downstream knows: the request it
  produces is shaped exactly like `7pm in London`'s, so the pair view, the
  footer, the zone lines and the chips all work unchanged. Note the direction
  is the *opposite* of a time with one zone — `8pm ET` is still 8pm in ET
  converted to local.
- **The bare-zone test is structural, never "did it resolve".** The tokenizer's
  `bareZoneTokens` offers the whole trimmed, normalised input as one zone token
  whenever the time match failed, so long as the text structurally *could* name
  a place; otherwise P1. It must not ask the chain, because a bare `Lodnon` has
  to reach P5's did-you-mean chips and a bare `CST` has to reach P4's picker —
  gating on resolution success would turn both into "couldn't find a time". The
  three rejections, each a shape rather than a lookup:
  - **starts with a digit** — no zone name does, and somebody who has typed
    digits is partway through a time (`12`, `13:00 am`, `25:00`, `6 et in
    london`);
  - **contains no letter** — names are made of words (`!!!`);
  - **contains a standalone conjunction** — the user wrote a conversion
    sentence and left out the time, so P1's "start with e.g. 14:30" is the
    useful answer, not "don't recognize 'london to paris'". Multi-word zone
    names are untouched: `east coast` and `south africa` contain no standalone
    `in`/`to`, and `porto` never did.
- **Digit-only input stays P1** (decided with item 22). `12` is not a time —
  the 24-hour form requires its minutes — and it is not a zone name either, so
  it could defensibly have become a P5 unknown zone. It does not: the first
  rejection above covers it, because "Couldn't find a time — start with e.g.
  14:30" is the useful half of the truth for a half-typed time, and
  "Don't recognize '12'" is not. `BareZoneInputTests
  .digitOnlyInputsStayP1RatherThanBecomingUnknownZones` pins it.
- **`now` is a time, never a zone** (item 23). The tokenizer's `leadingTime`
  accepts a standalone leading `now` wherever a clock time could start the
  input, leaving `Tokens.time` nil; everything after it splits as usual, so
  `now in Bangkok` is shaped like `7pm in Bangkok`. `InputParser` fills a nil
  time with the wall clock of `now` read in the *resolved source zone* — the
  device zone for `now in Bangkok` or a bare zone, ET for `now ET in London`.
  Bare `now` / `now in` is P2 with `time: nil` ("Convert now where?"). Only the
  leading word is checked, so `9am in now` is an ordinary P5 target
  (`NowKeywordTests`).
- **The defaulted side is marked, never silent.** A defaulted `ResolvedZone`
  carries `matchSource == .deviceLocalZone`, and the echo leads its existing
  parenthetical with `local` — `7:00 pm Los Angeles (local, UTC-8) → 3:00 am
  London (UTC+0) +1d`. The marker means "we assumed this", so typing your own
  zone's name is *not* marked even when it equals the device zone. The named
  side is unaffected: abbreviation expansion, P4 pickers and P5 chips all behave
  exactly as they do in a two-zone sentence.
- **The device zone is injected, like the date.** `TimeZone.current` is never
  read below the view — the zone arrives as a `localZone:` parameter through
  driver → presenter → parser, so a defaulted side can only come from the
  caller. Tests inject `FixedZones` and therefore assert exact `(local, …)`
  strings on any machine.
- **Canonical country zones.** Step 4 entries are either `.canonical(zone)` —
  the clock on the country's mainland street, so `portugal` → `Europe/Lisbon`
  and never the Azores — or `.noCanonicalClock([zones])` for the six countries
  with no national time (USA, Canada, Australia, Brazil, Russia, Mexico), which
  prompt. Ambiguous *abbreviations* (`CST`, `IST`) always prompt; there is no
  canonical pick for those.
  One continent rides the same mechanism (item 25): `antarctica` is a
  no-canonical-clock row of eight research stations, one per distinct clock;
  a station typed by name (`mcmurdo`) is just a step-3 city
  (`AntarcticaInputTests`).
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
- **The result band's label is keyed on *how the token resolved*, not on the
  zone** (item 21, 2026-10-23). `America/New_York` is `IN NEW YORK` when the
  user typed a city and `IN ET (EASTERN TIME)` when they typed the code,
  because those are two different questions about the same zone and answering
  them identically throws away the user's own word for it. The sub-line
  underneath follows: a place header names the zone and makes it concrete
  (`Brasilia Standard Time (São Paulo)`), while an abbreviation header — which
  has already named the zone twice — adds only the cities (`New York,
  Toronto`). `ResolvedZone.zoneLabel` is the whole rule, and it has two cases
  rather than five: everything that is not a curated abbreviation is a place,
  including countries, gazetteer hits, abbreviations our tables do not cover,
  and the device-local default, which keeps its `(local)` marker instead of
  growing a third case.
- **The zone name comes from Foundation; the cities come from us.**
  `TimeZone.localizedName(for: .generic)` — verified at runtime, not guessed:
  `America/Sao_Paulo` is "Brasilia Standard Time", `Europe/London` is "United
  Kingdom Time", `Asia/Tokyo` is "Japan Standard Time", `America/New_York` is
  "Eastern Time". `.standard` was the other candidate and is wrong for exactly
  the reason the line exists — it names today's offset rather than the zone, so
  London would read "Greenwich Mean Time" in July. Pinned to `en_US`, like
  every other string the app renders. The *cities* stay hand-curated, because
  naming 443 zones is not an editorial decision worth making: `ZoneRepresentative
  Cities` reads the two abbreviation tables backwards, keeping an entry only when
  the zone's own city appears in it. That rule is load-bearing — Foundation maps
  `MST` to `America/Phoenix`, whose curated cities are Denver and Calgary, two
  cities that observe daylight saving where Phoenix does not — and it folds
  diacritics, because the tables spell `São Paulo` properly and an identifier
  can only ever yield `Sao Paulo`.
- **UTC offsets left the result band and the box echo, and stayed everywhere
  else** (item 21). The echo subtitle is `Lisbon · 8:00 PM`, not `… · UTC+1`:
  the box echoes back what the user *typed*, and `UTC+1` is not something they
  typed. Disambiguation chips keep their offsets, because there the offset is
  the entire basis for choosing between two meanings of `CST`. The footer
  sentence is untouched — it was never about offsets, only the difference
  between two of them. And `ConversionResult.summary` (the Mac shell's one
  sentence) keeps every offset it had.
- **The source reading comes from the resolved instant**, not the requested
  time. On a spring-forward gap the echo therefore shows the shifted time
  (`2:30 am` typed → `3:00 am New York (UTC-4)`), which is how the user sees
  what happened. `ConversionResult.requestedTime` and `.wallClockDisposition`
  keep the original intent available.
- **Compact times are the colon made optional** (item 27, 2026-10-28). The
  minutes are always the last two digits, so `930` is 9:30 with no extra rule:
  the pattern simply cannot match a one-digit minute. The end-of-word lookahead
  rejects `15000` and `1500m` the same way it already rejected `12pmet`. Two
  digits stay P1; a lone `1234` is now P2 (a time, no zone)
  (`CompactTimeTests`).
- **Time-of-day canonical form is always 12-hour**, even for 24-hour input, per
  the spec's output examples. `23:15` echoes as `11:15 pm`.
- **A redundant meridiem is accepted, a contradictory one is not.** On hours
  outside 1–12 the `am`/`pm` adds nothing, so it is honoured when it agrees
  (`13:00 pm` = 13:00, `18pm` = 18:00, `0:30 am` = 00:30) and rejected as P1
  when it conflicts (`13:00 am`, `0:30 pm`). A contradictory meridiem must fail
  outright rather than fall through to the 24-hour pattern, which would parse
  the time and push the stray `am`/`pm` into the zone token.
- **The footer sentence is taken at the resolved instant too** (spec amendment
  2026-10-23). `ConversionResult.relativeOffsetSentence` subtracts the two
  zones' offsets *on the day asked about*, so for the few weeks each spring
  when the US has changed its clocks and Europe has not, London → New York
  reads `New York is 4 hours behind London.` rather than its usual 5. Non-whole
  gaps render decimally (`5.5 hours`, `5.75 hours`), an exact hour is singular,
  and two places on the same offset get `Madrid is the same time as Paris.`
  instead of a zero count.
- **The footer names both sides** (item 20, phase A — re-worded the same day by
  the iPad/Mac designs). It used to be a bare predicate, `4 hours behind
  Lisbon.`, which works under the iPhone's single huge time where the subject
  is unmistakable. Pages 2–4 put *two* times side by side, and there the same
  words become a riddle about which column they describe — so the target is
  named: `São Paulo is 4 hours behind Lisbon.` Adopted on every platform, one
  sentence, one implementation. The one exception is a zone compared with
  itself, which keeps the bare predicate rather than printing `London is the
  same time as London.`
- **`relativeOffsetPhrase` is the same relationship with both names stripped**
  — `4 hours behind`, `3 hours ahead`, `Same time`. Page 4's keyboard-up layout
  sets it under the arrow between the two columns, where the arrow is already
  pointing from source to target so no names are needed. Note `ahead` and not
  the sentence's `ahead of`: with nothing after it the preposition would
  dangle.
- **Regex patterns are computed, not stored.** `Regex` is not `Sendable`, so
  Swift 6 forbids it as static stored state; two tiny patterns are rebuilt per
  parse, which is immeasurable against a keystroke.

## Tests

`TimeConverterCore/Tests/` covers the spec's full fixture list — every example
string, each surviving prompt trigger, lenient spacing, `12 am`/`12 pm`, redundant and
contradictory meridiems, CST/IST ambiguity, Porto through the real bundled file
(which is also how resource bundling is verified), both DST-transition branches
and day rollover both ways. On top of that: raw-range mapping through case
folding, collapsed whitespace and emoji (`RawTextRangeTests`); the did-you-mean
suggester including eight typo rows lifted from `docs/qa-input-candidates.md`
§3 and the abbreviation guard (`ZoneSuggestionEngineTests`); item 21's header and
sub-line as a matrix with one row per resolution kind, the Foundation
zone-name assertions, the city index's self-consistency and determinism, and
the offsets that stayed (`ZoneLineTests`); the expanded echo
with its table-integrity checks (`AbbreviationEchoTests`); and local-zone
defaulting with injected device zones — both conjunction cases, the `(local)`
echo, the coast aliases, rollover on a defaulted side and chips on the one named
zone (`LocalZoneDefaultingTests`); bare-zone input against a fixed `now` with
minutes on it — every token shape, the minute-exact clock read in the injected
device zone, the `(local)` echo, P4 and P5 with a chip that rewrites the whole
bare token, DST correctness in both seasons, the structural rejections and the
digit-only decision (`BareZoneInputTests`); and the relative-offset footer, both as
pure string formatting over raw second counts and end to end through the engine
against real half-hour, three-quarter-hour and same-offset zone pairs
(`RelativeOffsetFooterTests`). Run with `scripts/test.sh --platform all`.

The UI layers that consume this module are documented in the repo-root
`README.md`: `TimeConverter/` (iOS) and `TimeConverterMac/` (the native
menu-bar app).
