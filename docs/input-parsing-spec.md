# Input Parsing Spec

Backlog item 2 — agreed with Olivier 2026-10-20. Governs how freeform input is
broken down, how zone tokens resolve, and which prompts the user is offered.
Implementation is item 3; UI wiring is item 4.

## Grammar

```
<input>       := <time> <source-zone> <conjunction> <target-zone>
<time>        := H[H]:mm                    (24-hour assumed)
               | H[H]mm                     (compact 24-hour, added 2026-10-28)
               | H[H][[:]mm] [space] am|pm  (12-hour; space optional on input)
<conjunction> := "in" | "to"                (closed list, case-insensitive)
<zone>        := abbreviation | city | country   (one or more words)
```

- ~~All four parts are required~~ **Amended 2026-10-22 (reverses the original
  reject-on-one-zone decision): a missing side defaults to the device's local
  zone, and the conjunction decides which side the named zone is.**
  - `7pm in London` (conjunction present) → London is the **target**; source
    defaults to local. `7pm East Coast` (no conjunction) → East Coast is the
    **source**; target defaults to local.
  - The default is made explicit in the echo: the defaulted side renders the
    resolved local zone with a `(local)` marker, e.g.
    `7:00 pm Los Angeles (local, UTC-7) → 3:00 am London (UTC+0) +1d` — the
    restated input/output is what makes the assumption visible.
  - A time with **no** zone at all ("7pm") still prompts — there is nothing to
    convert between.
- Matching is case-insensitive throughout; whitespace is collapsed before parsing.
- Examples that must parse: `12pm ET in London`, `12 pm ET in London`,
  `06:34 Portugal in PST`, `23:15 UK to Porto`, `9:30 am New York to Lisbon`.

## Time formats

| Pattern | Rule |
|---|---|
| `HH:mm` | 24-hour. Hours 0–23, minutes 00–59. `6:34` and `06:34` both valid. |
| `H[:mm] am/pm` | 12-hour. Hours 1–12. Minutes optional (`12pm` = 12:00 pm). |
| `HHmm` / `Hmm` | Compact 24-hour (added 2026-10-28, item 27): 3–4 digits, no colon. `1500` = 15:00, `0600` = 06:00, `930` = 09:30. Same ranges as `HH:mm`. A meridiem may follow (`600pm` = 6:00 pm, `1230 am` = 00:30) under the same redundant/contradictory rule. |

- **Lenient spacing**: `12pm`, `12 pm`, `12:30pm`, `12:30 pm` all accepted.
  The parsed interpretation is always echoed back in canonical form with the
  space (`12:00 pm`).
- `12 am` = 00:00, `12 pm` = 12:00 (standard convention).
- **Redundant-but-consistent am/pm is accepted; contradictory am/pm is
  rejected** (amended 2026-10-20): an hour of 13–23 with `pm` is valid and
  means the 24-hour time (`13:00 pm` = 13:00, `18pm` = 18:00); the same hour
  with `am` is a contradiction → P1. Symmetrically, hour 0 with `am`
  (`0:30 am` = 00:30) is accepted; hour 0 with `pm` is rejected.
- No date in the grammar: the time is "today" in the source zone.
- **Compact times** (amended 2026-10-28, backlog item 27). A leading run of
  3–4 digits with no colon is a 24-hour time. Ambiguity check, done against the
  tokenizer before implementing: no other token in the grammar is a bare
  leading number (zone names never start with a digit — item 22's structural
  rule), and before this amendment every such input was P1, so no input that
  used to convert changes meaning. The one reading question is three digits,
  settled by convention: **the last two digits are always the minutes**
  (`930` = 9:30, never 93:0; `130` = 1:30). Rejections, all P1: hours above
  23 or minutes above 59 (`2400`, `1260`, `960`), five or more digits
  (`15000`), and digits glued to letters (`1500m`, `1500et` — the time must
  end on a word boundary, exactly as `12pmet` already fails). Two digits stay
  P1 (`12` — item 23's decision: 24-hour needs its minutes). Consequences
  accepted: a 4-digit input with nothing after it is now a time with no zone
  (`1234` → P2 "Convert 12:34 pm where?") rather than P1, and a year typed at
  the start (`2026`) reads as 20:26 — there are no dates in the grammar.

## Tokenization

1. Trim, collapse whitespace, lowercase a working copy.
2. Match the time at the start of the string (regex above, longest match), or
   a standalone leading `now` (item 23 — time = current clock).
   **No match** (amended 2026-10-23, item 22): the whole working copy becomes a
   single target-side zone token and the time becomes "now" — unless it fails
   the structural test in Architecture notes, in which case P1.
3. Scan the remaining words for the **first** standalone conjunction (`in`/`to`).
   Words before it are the source-zone token; words after it are the target-zone
   token. (First-match scan means a city containing "in"/"to" as a *whole word*
   between the zones can't occur; conjunctions inside multi-word names like
   "Porto" are not standalone words and don't trigger.)
4. Empty source or target token → the corresponding "missing side" prompt.

## Zone resolution

A zone token runs through an ordered chain of resolvers. Each resolver returns
zero or more candidates `(tz identifier, display name, source of match)`; the
chain stops at the **first resolver with ≥1 candidate**.

1. **Alias table** (hand-rolled, versioned in code). DST-neutral and colloquial
   abbreviations Foundation doesn't know: `ET→America/New_York`,
   `PT→America/Los_Angeles`, `CT`, `MT`, `UK→Europe/London`, `CET→Europe/Paris`…
   Deliberately ambiguous entries list all meanings: `CST→[America/Chicago,
   Asia/Shanghai]`, `IST→[Asia/Kolkata, Europe/Dublin]`.
2. **Foundation abbreviations** — `TimeZone.abbreviationDictionary` (PST, EST,
   GMT, …).
3. **tz-database city match** — token against the final component of every
   `TimeZone.knownTimeZoneIdentifiers` entry, underscores→spaces
   (`new york` → `America/New_York`, `london` → `Europe/London`).
4. **Country table** (hand-rolled). Country names/common forms → zone list,
   with an optional **canonical zone** per entry. Single-zone countries resolve
   directly (`japan→Asia/Tokyo`). Multi-zone countries with a dominant national
   clock resolve to their designated canonical zone — the zone a clock on the
   mainland street shows: `portugal→Europe/Lisbon` (not Azores),
   `spain→Europe/Madrid` (not Canaries). DST is automatic via the IANA zone.
   Countries with **no** single national clock (`usa`, `canada`, `australia`,
   `brazil`, `russia`, `mexico`) return all candidates → P4 prompt.
   (Amended 2026-10-20: canonical defaults replace always-prompt for countries;
   abbreviations like CST/IST keep the always-prompt rule — no canonical pick.)
   **Continent-as-country row** (amended 2026-10-28, item 25): `antarctica`
   is a no-canonical-clock entry whose candidates are research-station zones
   from the tz database's `Antarctica/*` area — one station per distinct
   offset rule, eight chips, each labelled with the station name (the
   identifier city): McMurdo (UTC+13/+12, also stands for the South Pole link),
   Macquarie (+11/+10), Casey (+8), Davis (+7), Mawson (+5, also Vostok's
   offset), Syowa (+3), Troll (+0/+2), Rothera (−3, also Palmer's). Listing all
   twelve identifiers was rejected: four rows would duplicate another row's
   clock, and Dumont d'Urville (+10) is left out because its only label is the
   identifier spelling `DumontDUrville`; it still resolves when typed.
   Individual stations (`mcmurdo`, `south pole`, `vostok`) need no entry — the
   step-3 city resolver already indexes the `Antarctica` area.
5. **Offline fallback list** (bundled data file, not code). Cities absent from
   the tz db. Seeded with a handful of QA entries only (e.g.
   `porto→Europe/Lisbon`, `manchester→Europe/London`); architected so a larger
   gazetteer can replace the file later without touching the resolver chain.
   **Grown 2026-10-28 (item 26)**: the file now carries ~300 names — the
   world's ~200 largest cities plus every national capital that is not already
   a tz identifier city — each mapped to its correct IANA zone (`mumbai` →
   `Asia/Kolkata`, `barcelona` → `Europe/Madrid`, `rio` → `America/Sao_Paulo`,
   `calgary` → `America/Edmonton`). Rules: a name an earlier step already
   resolves is omitted (it would be unreachable); a name shared by places in
   different zones with no clear winner is either left out (`portland`,
   `valencia`, `hamilton`, `victoria`, `st john's`) or lists both zones so it
   prompts (`san jose` = California / Costa Rica, `washington` = DC / state);
   a clear winner is mapped with a comment (`birmingham` → England).
   **Grown again 2026-10-30 (item 34)**: ~3,100 names. The brief was "cities
   of Portland's notoriety — regional capitals": every US state capital and
   major US city, Canadian provincial capitals, Mexican and Brazilian state
   capitals, UK and Irish cities, European regional capitals (German states,
   Italian regions, Spanish autonomous communities, French regions), Russian
   regional capitals, Indian state capitals, Chinese provincial capitals,
   Japanese prefectural capitals, South-East Asian and Australian regional
   centres, Pacific islands and territories — plus well-known regions (US
   states, Canadian provinces, `bavaria`, `tuscany`, `kerala`, `queensland`)
   and destinations (`aspen`, `zermatt`, `uluru`, `bora bora`). The split-name
   rule changed: the names left out in item 26 now list every notable zone so
   they prompt (`portland` = Oregon / Maine; `springfield`, `hamilton`,
   `victoria`, `santa cruz` three ways), and a long form (`portland oregon`,
   `hamilton ontario`) resolves directly. Two zones that merely share a clock
   are never listed together. Deliberately excluded: neighbourhoods and
   suburbs, towns well below that notability, ordinary words and first names
   that happen to be places (`orange`, `mary`, `young`), two-to-four-letter
   codes (those belong in the alias table; `dc` and `hcmc` are the
   exceptions), and sovereign countries (country table).

Outcomes per token:
- **1 candidate** (including a country's canonical zone) → resolved; the echoed
  interpretation always names the zone actually used, so the Lisbon-not-Azores
  choice is visible.
- **>1 candidate** → prompt (disambiguation picker). Applies to ambiguous
  abbreviations (CST, IST) and no-canonical-clock countries.
- **0 candidates** from every resolver → unknown-token prompt.
- tz-db legacy country identifiers (`Portugal`, `Japan`, `GB`) must NOT be
  matched by the city resolver (step 3) — country handling belongs to step 4
  so the canonical/prompt policy applies.

## Prompts

| ID | Trigger | Prompt behavior |
|---|---|---|
| P1 | No parseable time at start of input **and** the input cannot be a bare zone token (narrowed 2026-10-23, item 22 — see the bare-zone rule in Architecture notes) | "Couldn't find a time — start with e.g. 14:30 or 2:30 pm" |
| P2 | No zone anywhere in the input (amended 2026-10-22: single missing sides no longer prompt — they default to local) | "Convert {time} where? Add a timezone, city, or country" |
| P3 | *(retired 2026-10-22 — absorbed by the local-default rule; a conjunction with nothing after it still renders P2)* | |
| P4 | Ambiguous zone token | Picker listing every candidate with its current UTC offset and a representative city; selection completes the conversion |
| P5 | Unknown zone token | "Don't recognize '{token}'" + hint that timezones, major cities, and countries work |

Prompts are returned by the parser as values (not UI) so they're unit-testable;
item 4 renders them.

## Conversion & output

- Interpret the time as **today** in the source zone, then convert.
- Echo the full interpretation back canonically so mistakes are visible:
  `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0)`, including a +1d/−1d
  marker when the date rolls over.
- **Abbreviation inputs echo expanded** (added 2026-10-21): when a zone was
  resolved from an abbreviation/alias, the echo shows the expanded name with
  representative cities, not the bare identifier city — `12pm ET in London` →
  `12:00 pm Eastern Time (New York, Toronto) …`. Alias and abbreviation
  resolver entries carry a display name and one or two representative cities.
  City- and country-resolved tokens echo as before (`London`, `Lisbon`).
- DST edges on transition days: a nonexistent local time resolves forward to the
  next valid instant; an ambiguous (repeated) time takes the earlier instant.
  The displayed UTC offsets make the choice visible; no prompt.

## Architecture notes (for item 3)

- `InputParser.parse(String) -> ParseOutcome` where `ParseOutcome` is
  `.request(ConversionRequest)` / `.prompt(Prompt)` — pure, no UI, no clock
  access (current date injected for testability).
- Resolvers conform to a `ZoneResolver` protocol and run as an ordered array,
  so the fallback gazetteer (step 5) is swappable data, not new code.
- Test fixtures: every example string in this spec, each prompt trigger, the
  lenient-spacing variants, `12 am`/`12 pm`, CST/IST ambiguity, Porto via the
  fallback list, and a DST-transition conversion.
- **Relative-offset footer** (added 2026-10-23, from the iOS design; re-worded
  2026-10-23 by the iPad/Mac designs, item 20): every conversion carries a
  footer sentence derived from the offset difference at the resolved instant:
  `São Paulo is 4 hours behind Lisbon.` / `London is 3 hours ahead of New
  York.` / `Madrid is the same time as Paris.` — "behind/ahead" is the target
  relative to the source; both place names are the sides' display names;
  non-whole offsets render decimally ("4.5 hours", "5.75 hours"). The subject
  was added because the iPad and Mac layouts put two times side by side, where
  the original bare predicate (`4 hours behind Lisbon.`) does not say which
  column it describes. One exception: a zone compared with itself keeps the
  bare predicate, since `London is the same time as London.` reads as a bug.
  A names-free variant, `relativeOffsetPhrase` (`4 hours behind`, `3 hours
  ahead`, `Same time`), serves the keyboard-up layout that sets it under the
  arrow between the two columns.
- **Result-band labels and de-UTC'd echo** (amended 2026-10-23, item 21): the
  input-box echo subtitle drops the UTC offset (`Lisbon · 8:00 PM`). The line
  under the big time is no longer a UTC offset; it is keyed on how the TARGET
  resolved — place (city/country/gazetteer/local-default): header `IN <PLACE>`,
  sub-line = zone generic name + representative cities (`BRASILIA STANDARD
  TIME (SÃO PAULO)`); curated abbreviation: header `IN <CODE> (<EXPANDED>)`,
  sub-line = cities only (`NEW YORK, TORONTO`). Zone names via
  TimeZone.localizedName(.generic, en_US). NEXT/PREVIOUS DAY rides the
  sub-line. Chips keep UTC offsets; the relative-offset footer sentence and
  the Mac echoLine (offsets included) are unchanged.
- **Bare-zone input = now** (added 2026-10-23, backlog item 22): an input that
  is ONLY a zone token, no time ("ET", "Tokyo", "east coast") converts the
  CURRENT device clock to that zone: time = now (hours and minutes, injected
  `now`), source = device local zone, target = the named zone. The echo marks
  the assumption — the source side renders with the existing `(local)` marker
  and the current time; prompts P4/P5 apply to the token as usual. P1 keeps
  firing only for inputs that contain neither a parseable time nor a lone
  resolvable zone. Existing rule unchanged: "8pm ET" = 8pm in ET → local.
  - **The rule is structural, not resolution-dependent** (implementation
    decision, item 22). When the time match fails, the whole trimmed/normalised
    input is offered to the resolver chain as a single **target**-side zone
    token — the chain is never consulted to decide *whether* it is one, because
    a bare unknown token ("Lodnon") must reach P5's did-you-mean chips and a
    bare ambiguous one ("CST") must reach P4's picker. Three structural
    rejections fall back to P1: the input is empty or whitespace; it begins with
    a digit (no zone name does, and digits read as a half-typed time — "12",
    "13:00 am", "25:00", "6 et in london"); it contains no letter at all
    ("!!!"); or it contains a standalone conjunction, meaning the user wrote a
    conversion sentence and omitted the time ("london to paris" → P1, not an
    unknown zone). Multi-word zone names are unaffected — "east coast" and
    "south africa" contain no standalone "in"/"to".
  - **Digit-only input is P1, deliberately.** Bare "12" is not a time (the
    24-hour form requires minutes) and is not a zone name, so either prompt
    could be argued. It resolves to P1: a user typing digits is starting a
    time, and "Couldn't find a time — start with e.g. 14:30" is the useful
    answer where "Don't recognize '12'" is not.
- **`now` as the time** (added 2026-10-28, backlog item 23): the leading time
  may be the keyword `now` (case-insensitive, a standalone word — `nowhere` is
  not it). `now in Bangkok` / `now to Bangkok` = the current device clock
  (hours and minutes) converted to Bangkok, source = device local zone — the
  same shape as `7pm in Bangkok`. `now ET in London` reads the clock in the
  named source (ET), so the converted instant is the real present. `now`,
  `now in` with no zone are P2 ("Convert now where? …"). **Input only:** `now`
  is never a zone — `9am in now` is P5 on the target token.
