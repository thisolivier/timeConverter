# Input Parsing Spec

Backlog item 2 — agreed with Olivier 2026-10-20. Governs how freeform input is
broken down, how zone tokens resolve, and which prompts the user is offered.
Implementation is item 3; UI wiring is item 4.

## Grammar

```
<input>       := <time> <source-zone> <conjunction> <target-zone>
<time>        := HH:mm                      (24-hour assumed)
               | H[H][:mm] [space] am|pm    (12-hour; space optional on input)
<conjunction> := "in" | "to"                (closed list, case-insensitive)
<zone>        := abbreviation | city | country   (one or more words)
```

- All four parts are **required**. A lone zone ("3pm in Tokyo", "06:34 Portugal")
  is rejected with a prompt for the missing side — we never silently assume the
  device's local zone.
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
4. **Country table** (hand-rolled). Country names/common forms → zone list.
   Multi-zone countries return all their zones: `portugal→[Europe/Lisbon,
   Atlantic/Azores]`, `usa→[the six primary US zones]`. Single-zone countries
   resolve directly (`japan→Asia/Tokyo`).
5. **Offline fallback list** (bundled data file, not code). Cities absent from
   the tz db. Seeded with a handful of QA entries only (e.g.
   `porto→Europe/Lisbon`, `manchester→Europe/London`); architected so a larger
   gazetteer can replace the file later without touching the resolver chain.

Outcomes per token:
- **1 candidate** → resolved.
- **>1 candidate** → **always prompt** (disambiguation picker). No silent
  defaults, ever.
- **0 candidates** from every resolver → unknown-token prompt.

## Prompts

| ID | Trigger | Prompt behavior |
|---|---|---|
| P1 | No parseable time at start of input | "Couldn't find a time — start with e.g. 14:30 or 2:30 pm" |
| P2 | Missing source zone | "Where is {time}? Add a zone before '{conjunction}'" |
| P3 | Missing target zone / no conjunction found | "Convert {time} {source} to where? Add 'in' or 'to' + a place" |
| P4 | Ambiguous zone token | Picker listing every candidate with its current UTC offset and a representative city; selection completes the conversion |
| P5 | Unknown zone token | "Don't recognize '{token}'" + hint that timezones, major cities, and countries work |

Prompts are returned by the parser as values (not UI) so they're unit-testable;
item 4 renders them.

## Conversion & output

- Interpret the time as **today** in the source zone, then convert.
- Echo the full interpretation back canonically so mistakes are visible:
  `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0)`, including a +1d/−1d
  marker when the date rolls over.
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
