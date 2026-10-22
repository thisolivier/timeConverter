# Input Parsing Spec

Backlog item 2 — agreed with Olivier 2026-10-20. Governs how freeform input is
broken down, how zone tokens resolve, and which prompts the user is offered.
Implementation is item 3; UI wiring is item 4.

## Grammar

```
<input>       := <time> <source-zone> <conjunction> <target-zone>
<time>        := H[H]:mm                    (24-hour assumed)
               | H[H][:mm] [space] am|pm    (12-hour; space optional on input)
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

## Tokenization

1. Trim, collapse whitespace, lowercase a working copy.
2. Match the time at the start of the string (regex above, longest match).
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
5. **Offline fallback list** (bundled data file, not code). Cities absent from
   the tz db. Seeded with a handful of QA entries only (e.g.
   `porto→Europe/Lisbon`, `manchester→Europe/London`); architected so a larger
   gazetteer can replace the file later without touching the resolver chain.

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
| P1 | No parseable time at start of input | "Couldn't find a time — start with e.g. 14:30 or 2:30 pm" |
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
