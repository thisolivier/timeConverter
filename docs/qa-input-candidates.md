# QA Input Candidates

**DRAFT — for Olivier's review.** Not a test suite yet. This is the candidate
pool of things a real person might type fast into the single input field, with
the behavior `docs/input-parsing-spec.md` *as written* would produce. Review,
cull, and promote the survivors into fixtures for item 3.

Expected-behavior column uses: `parse OK`, `P1`–`P5` (spec prompt IDs), or
`out of scope`. Where the spec genuinely doesn't say, the note says **spec gap**
rather than guessing. Nothing here invents behavior.

Two spec mechanics drive most of the surprises, so they're worth stating up front:

- **The 24-hour form requires a colon.** `HH:mm` only — so `1230`, `12.30pm`,
  `12h30`, and a bare `7` never match a time and fall to P1.
- **The conjunction list is closed at `in` | `to`.** Anything else (`at`, `->`,
  `=`, omitted) means "no conjunction found" → **P3**, never P5. So a huge class
  of natural phrasings all collapse into one prompt. See section 4.
- **Punctuation is never stripped** — only whitespace is collapsed — so a
  trailing `?` or `.` rides along into the zone token and produces P5.

---

## 1. Happy path

Valid per the grammar: time at the start, source zone, `in`/`to`, target zone.

### 24-hour times

| Input | Expected behavior | Notes |
|---|---|---|
| `14:30 ET in London` | parse OK | Baseline. Alias → tz db city. |
| `23:15 UK to Porto` | parse OK | Spec example. Porto via resolver 5 fallback. |
| `06:34 Portugal in PST` | parse OK *or* P4 | Spec example, but see §6 — `portugal` is a 2-candidate country. Contradiction. |
| `6:34 UK to Lisbon` | parse OK | Single-digit hour, no leading zero. |
| `00:00 GMT in Tokyo` | parse OK | Midnight boundary; expect `+0d`/date echo. |
| `0:05 UTC in London` | parse OK? | `UTC` isn't in the alias list; relies on a tz-db `UTC` identifier. **Spec gap** — is `UTC`/`Z` in scope? |
| `09:00 CET in Dublin` | parse OK | Alias `CET→Europe/Paris`. |
| `12:00 PST in Berlin` | parse OK | Resolver 2 (Foundation abbreviations). |
| `21:30 london in new york` | parse OK | All lowercase, multi-word target. |
| `19:59 Madrid to Phoenix` | parse OK | Phoenix = no-DST target, good offset check. |
| `23:59 Tokyo in London` | parse OK | Expect a `−1d` marker. |
| `03:00 Sydney to Vancouver` | parse OK | Cross-dateline, expect a day marker. |

### 12-hour times, with and without the space

| Input | Expected behavior | Notes |
|---|---|---|
| `12pm ET in London` | parse OK | Spec example. Echo as `12:00 pm`. |
| `12 pm ET in London` | parse OK | Spec example. Same result as above. |
| `9:30 am New York to Lisbon` | parse OK | Spec example. |
| `9:30am New York to Lisbon` | parse OK | Lenient spacing. |
| `12:30pm ET in London` | parse OK | |
| `12:30 pm ET in London` | parse OK | |
| `1pm PT in Tokyo` | parse OK | Minutes omitted. |
| `1 PM PT in Tokyo` | parse OK | Uppercase meridiem. |
| `12am ET in London` | parse OK | Must be 00:00, not 12:00. |
| `7:05pm CET in Toronto` | parse OK | Leading-zero minutes. |
| `10:00 am Dublin in Auckland` | parse OK | `10:00 am` — colon + meridiem together. |

### Multi-word cities

| Input | Expected behavior | Notes |
|---|---|---|
| `3pm ET in new york` | parse OK | `new york` → `America/New_York` (underscore → space). |
| `3pm New York in Los Angeles` | parse OK | Multi-word on both sides. |
| `8am Los Angeles to Hong Kong` | parse OK | |
| `9am ET in Sao Paulo` | parse OK | Unaccented. `São Paulo` with accent is untested — **spec gap** on diacritic folding. |
| `9am ET in Indianapolis` | parse OK | Final component of a 3-part identifier (`America/Indiana/Indianapolis`). Confirm resolver 3 takes the *last* component. |

### Countries and abbreviation-to-abbreviation

| Input | Expected behavior | Notes |
|---|---|---|
| `10:00 Japan in UK` | parse OK | Single-zone country → alias. |
| `10am Germany to India` | parse OK | Both single-zone per the country table. |
| `10am France in Japan` | parse OK | Unless the country table includes French overseas zones — see §6. |
| `9am India in Tokyo` | parse OK | Control: `India` *starts with* "in" but isn't a standalone word — must not trigger the conjunction scan. |
| `9am Toronto in London` | parse OK | Control: `Toronto` contains "to"; spec calls this out explicitly. |
| `12pm ET in PT` | parse OK | Alias on both sides. |
| `9am EST to PST` | parse OK | Foundation abbreviations both sides. |
| `16:00 CET in JST` | parse OK? | `JST` isn't in the alias list — depends on `abbreviationDictionary` contents. Verify, then decide if it needs an alias. |

---

## 2. Case, whitespace, and format variants

| Input | Expected behavior | Notes |
|---|---|---|
| `12PM ET IN LONDON` | parse OK | Matching is case-insensitive throughout. |
| `12pm et in london` | parse OK | |
| `  12pm   ET   in   London  ` | parse OK | Trim + collapse. |
| `12pm→TAB→ET→TAB→in→TAB→London` (tabs) | parse OK | "Collapse whitespace" presumably covers `\t`; **spec gap** on which characters count. |
| `12pm ET in London` + trailing newline | parse OK | Same gap as above. |
| `12pm ET in London` with non-breaking spaces | **spec gap** | Pasted from Slack/web. Does NBSP (U+00A0) collapse? Likely not → P5 on a glued token. |
| `12pm ET in London.` | P5 | Target token is `london.` — punctuation never stripped. High-frequency. |
| `12pm ET in London?` | P5 | Same. Very likely in real use. |
| `12pm, ET, in London` | P5 | Source token is `et,`. |
| `"12pm ET in London"` | P1 | Leading quote means no time match at position 0. |
| `12.30pm ET in London` | P1 | Dot separator; `HH:mm` needs a colon. Common UK/European habit. |
| `1230 ET in London` | P1 | No colon → no 24h match. Common fast-typing shorthand. |
| `1230pm ET in London` | P1 | `12` isn't followed by a meridiem, `1230` isn't `HH:mm`. |
| `12h30 ET in London` | P1 | French style. |
| `12:3 ET in London` | P1 | `mm` is two digits. **Spec gap** — is a single-digit minute worth accepting? |
| `12 : 30 ET in London` | P1 | Spaces around the colon; collapse doesn't help. |
| `12:30:00 ET in London` | P5 | Time matches `12:30`; remainder `:00` joins the source token → `:00 et`. See §5. |
| `12：30 ET in London` (full-width colon) | P1 | IME artifact. **Spec gap** on Unicode normalization. |
| `12pm—ET in London` (em dash, no spaces) | P5 | Source token `—et`. |
| `TWELVE PM ET IN LONDON` | P1 | Word numerals out of scope. |

---

## 3. Typos — realistic fast-typing errors

### Misspelled target or source place → P5

| Input | Expected behavior | Notes |
|---|---|---|
| `12pm ET in Lodnon` | P5 | Transposition. The single most likely real typo. |
| `12pm ET in Londn` | P5 | Dropped letter. |
| `12pm ET in Lonndon` | P5 | Doubled letter. |
| `12pm ET in Toyko` | P5 | Transposition. |
| `12pm ET in Tokio` | P5 | Plausible non-English spelling; alias candidate. |
| `12pm ET in Pairs` | P5 | Transposition that is also a real English word. |
| `12pm ET in new yrok` | P5 | Transposition inside a multi-word city. |
| `12pm ET in Los Angelos` | P5 | Very common misspelling. |
| `12pm ET in Newyork` | P5 | Missing space. Alias candidate. |
| `12pm ET in Lisboa` | P5 | Endonym, not a typo — alias candidate. |
| `12pm ET in Munich` | P5 | Correctly spelled but absent from the tz db. Shows the gazetteer gap, not a typo. |
| `06:34 Portgual in PST` | P5 | Transposition of the spec's own example. |

### Mistyped zone abbreviations → P5

| Input | Expected behavior | Notes |
|---|---|---|
| `12pm RT in London` | P5 | E→R, adjacent key. |
| `12pm PSR in London` | P5 | |
| `12pm PTS in London` | P5 | Transposed `PST`. |

### Mistyped time → mostly P1, sometimes a silent swallow

| Input | Expected behavior | Notes |
|---|---|---|
| `12pn ET in London` | P1 | M→N, adjacent key. Very likely. |
| `12om ET in London` | P1 | P→O, adjacent key. |
| `12pmm ET in London` | P5 | Time matches `12pm`; stray `m` joins the source → `m et`. Misleading prompt — would be better as P1 or a "didn't understand" prompt. |
| `12:300 ET in London` | P5 | Time matches `12:30`; `0` joins the source → `0 et`. Same problem. |
| `9:3o am ET in London` | P1 | Zero→letter-o. |
| `l2pm ET in London` | P1 | Lowercase L for 1. |
| `O6:34 Portugal in PST` | P1 | Letter O for zero. |

### Mistyped conjunction → P3 (not P5)

| Input | Expected behavior | Notes |
|---|---|---|
| `1pm ET ni London` | P3 | Transposed `in`. The canonical fast-typing conjunction typo. |
| `1pm ET i London` | P3 | Dropped letter. |
| `1pm ET ot London` | P3 | Transposed `to`. |
| `1pm ET too London` | P3 | Doubled letter; not a standalone `to`. |
| `1pm ET tO London` | parse OK | Lowercasing makes this valid — good regression case. |
| `1pm ETin London` | P3 | Missing space *before* the conjunction; `etin` isn't a conjunction, so no conjunction is found. |
| `1pm ET inLondon` | P3 | Missing space *after*; `inlondon` isn't standalone either. |
| `1pmET in London` | parse OK | Time regex isn't word-bounded, so `12pm`+`ET` glued still works. **Spec gap** — confirm this is intended, since it's inconsistent with the two rows above. |

---

## 4. Alternative conjunctions and phrasings (priority section)

Every row here is something people actually type. Under the spec's closed
`in`/`to` list, almost all of them produce the **same P3 prompt**, which makes
P3 the app's most-hit failure mode. Last column is my add/reject call.

| Input | Expected behavior | Notes |
|---|---|---|
| `12pm ET at London` | P3 | **ADD `at`.** Very common; no collision risk with place names. |
| `12pm ET into London` | P3 | **ADD `into`.** Natural, zero ambiguity. |
| `12pm ET for London` | P3 | **ADD `for`.** Common ("9am ET for London"). |
| `9am ET vs London` | P3 | **ADD `vs`.** Comparison framing is very common. |
| `9am ET versus London` | P3 | **ADD `versus`.** Cheap once `vs` exists. |
| `9am ET → London` | P3 | **ADD `→`.** Spec's own output format uses `→`, so users will copy it back in. |
| `9am ET -> London` | P3 | **ADD `->`.** ASCII form of the same. |
| `9am ET => London` | P3 | **ADD `=>`.** |
| `9am ET = London` | P3 | **ADD `=`.** |
| `9am ET == London` | P3 | **ADD** (normalize runs of `=`). |
| `9am ET - London` | P3 | **ADD with care** — collides with ranges (`2-3pm`) and hyphenated names (`Port-au-Prince`, `Winston-Salem`). Suggest: only when surrounded by spaces. |
| `9am ET — London` (em dash) | P3 | **ADD** (spaced only, same rule). |
| `9am ET / London` | P3 | **ADD `/`** (spaced only). |
| `9am ET \| London` | P3 | **ADD `\|`.** |
| `9am ET, London` | P3 | **ADD `,` as a conjunction** — but only after punctuation stripping is specified, or `et,` breaks the source first. |
| `9am ET London` | P3 | **Conjunction omitted — highest-value case in this doc.** Needs a greedy "longest resolvable trailing zone" split, which conflicts with multi-word cities (`9am ET New York`). Recommend a spike, not a quick fix. **Spec gap.** |
| `from 9am ET to London` | P1 | **ADD a leading-filler strip** (`from`, `convert`, `what is`, `whats`). Otherwise the time isn't at position 0. |
| `9am from ET to London` | P5 | Source token is `from et`. Same strip, applied inside the source. |
| `convert 9am ET to London` | P1 | Same leading-filler strip. |
| `9am ET in to London` | P5 | Target token `to london`. **Recommend stripping a leading conjunction from each side token.** |
| `9am ET in in London` | P5 | Doubled conjunction → target `in london`. Same fix. |
| `9am ET to to London` | P5 | Same. |
| `9am ET in London time` | P5 | Target `london time`. **Recommend stripping trailing `time` / `local time` / `local`.** |
| `9am ET to London UK` | P5 | `City Country` qualifier unsupported. **Spec gap** — worth supporting given §6's collisions (`Birmingham UK`). |
| `9am ET is what in London` | P5 | First conjunction is the later `in`, so the source becomes `et is what`. Shows noise words poisoning the source side. |
| `9am ET as London` | P3 | **REJECT** — rare, and `as` is a plausible word fragment. |
| `9am ET then London` | P3 | **REJECT** — rare. |
| `9am ET becomes London` | P3 | **REJECT.** |
| `9am ET equals London` | P3 | **REJECT** (keep the symbol `=`, skip the word). |
| `9am ET when it's London` | P3 | **REJECT** — the phrasing implies an inverted direction. |
| `what time is it in London when it's 9am ET` | P1 | **REJECT** — needs clause reordering; out of scope. |
| `9am ET to; London` | P3 | `to;` isn't standalone. Fixed for free by punctuation stripping. |
| `9am ET IN London` | parse OK | Case-insensitive control. |
| `9am ET In London` | parse OK | Control. |

---

## 5. Out of scope but plausible

| Input | Expected behavior | Notes |
|---|---|---|
| `in 3 hours in Tokyo` | P1 | Relative time. P1's wording ("start with e.g. 14:30") is at least on-point. |
| `now in Tokyo` | P1 | Extremely likely first-run input. Consider a dedicated hint. |
| `noon ET in London` | P1 | **Recommend adding** `noon`→12:00. Cheap, high value. |
| `midnight ET in London` | P1 | **Recommend adding** `midnight`→00:00. |
| `midday UK in Tokyo` | P1 | **Recommend adding** `midday`→12:00. |
| `12 noon ET in London` | P1 | `12` alone isn't a valid 24h time. |
| `tomorrow 9am Tokyo in London` | P1 | Date word first → no time at position 0. |
| `9am tomorrow Tokyo in London` | P5 | Source becomes `tomorrow tokyo`. |
| `Dec 25 9am ET in London` | P1 | |
| `9am Dec 25 ET in London` | P5 | Source `dec 25 et`. |
| `2026-01-01 00:00 UTC in Tokyo` | P1 | ISO date prefix. |
| `Monday 9am ET in London` | P1 | |
| `2-3pm ET in London` | P1 | Range. `2-3pm` has no meridiem directly after `2`. |
| `2pm-3pm ET in London` | P5 | Time matches `2pm`; source becomes `-3pm et`. Misleading prompt. |
| `9am to 5pm ET in London` | P2 | **Nasty.** Time `9am`, then the first standalone conjunction is the `to` at position 0 of the remainder → empty source → "Where is 9:00 am?" The user asked for a range and gets asked for a source zone. |
| `what time is it in Tokyo` | P1 | |
| `what's 3pm ET in London` | P1 | Leading filler; see §4's strip recommendation. |
| `whats 3pm ET in London?` | P1 | P1 fires before the trailing `?` matters. |
| `12:30:45 ET in London` | P5 | Seconds. Source becomes `:45 et`. **Spec gap** — decide between tolerate-and-drop or an explicit P1. |
| `7:30 New York in London` | **parse OK as 07:30** | **Silent misinterpretation** — the user almost certainly meant 7:30 pm or am. Nothing in the spec flags a bare `H:mm` in the 1–12 range. Highest-risk row in the doc. |
| `7 New York in London` | P1 | No colon, no meridiem. |
| `7.30 New York in London` | P1 | |
| `UTC+5 in London` | P1 | No time present. |
| `12:00 UTC+5 in London` | P5 | Offsets aren't in any resolver. **Spec gap** — plausible addition. |
| `+0530 to EST` | P1 | |
| `9am ET in UTC-8` | P5 | Offset as a target. |
| `12:00 Z in Tokyo` | P5 (probably) | Depends on `abbreviationDictionary`. **Spec gap** on `Z`/`Zulu`. |

---

## 6. Ambiguity traps

| Input | Expected behavior | Notes |
|---|---|---|
| `12pm CST in London` | P4 | Alias lists Chicago + Shanghai. Spec fixture. |
| `12pm London in CST` | P4 | Ambiguity on the *target* side — confirm the picker handles either side. |
| `12pm IST in London` | P4 | Kolkata + Dublin. (Israel is a third real meaning — **spec gap**: should the alias list all three?) |
| `9am CST to IST` | P4 ×2 | **Spec gap** — both sides ambiguous. One picker then another? One combined? Undefined. |
| `06:34 Portugal in PST` | **contradiction** | Listed in the spec as "must parse", but resolver 4 gives `[Europe/Lisbon, Atlantic/Azores]` and ">1 → always prompt". Unless a legacy tz-db identifier `Portugal` short-circuits at resolver 3 — which the spec never says is in or out of scope. Must be resolved before implementation. |
| `9am USA in London` | P4 | Six zones. |
| `9am US in London` | P4 or P5 | Depends on whether the country table carries `US` as a common form. **Spec gap.** |
| `9am United States in London` | P4 | Multi-word country. |
| `9am Australia in London` | P4 | |
| `9am Brazil in London` | P4 | |
| `9am Russia in London` | P4 | 11 zones — picker needs to survive a long list. |
| `9am Spain in London` | P4 | Mainland + Canary. Users will not expect a prompt here. |
| `9am France in London` | P4 or parse OK | Hinges on whether the country table includes overseas territories. **Spec gap** — recommend an explicit "metropolitan/primary zone only" rule, or P4 everywhere and accept the friction. |
| `9am New Zealand in London` | P4 | Auckland + Chatham. Same unexpected-prompt problem. |
| `9am ET in Georgia` | **parse OK → Asia/Tbilisi** | **Silently wrong for most users.** The country table resolves it single-candidate; the US state never becomes a candidate because US states aren't in any resolver. No prompt, no visible warning beyond the echoed city. |
| `9am ET in Jordan` | parse OK → Asia/Amman | Same shape: country wins, US place name never considered. |
| `9am ET in Portland` | P5 | Absent from the tz db, so the OR-vs-ME ambiguity never even surfaces — the user just gets "don't recognize". Argues for the gazetteer carrying ambiguity, not just one-to-one rows. |
| `9am ET in Cambridge` | P5 | UK vs MA. Same point. |
| `9am ET in Birmingham` | P5 | UK vs AL. Same point. |
| `9am ET in San Jose` | P5 | CA vs Costa Rica. Same point. |
| `9am ET in Washington` | P5 | DC vs state. |
| `9am ET in Santiago` | parse OK → America/Santiago | Chile wins silently; Santiago de Compostela / Santiago de Cuba ignored. Acceptable, but the echo line is the only signal. |
| `9am ET in Japan` | parse OK | May resolve at resolver 3 (legacy identifier `Japan`) instead of resolver 4. Same answer here, but see next row. |
| `9am ET in Turkey` | parse OK | **Spec gap** — `knownTimeZoneIdentifiers` includes backward/legacy aliases (`Portugal`, `Japan`, `Turkey`, `Egypt`, `Cuba`, `Israel`, `Iceland`, `Singapore`, `GB`, `US/Pacific`, `Zulu`…). Because resolver 3 runs *before* the country table, those countries silently bypass multi-zone disambiguation. Must decide whether to filter legacy identifiers. |
| `9am ET in EST` | parse OK | Foundation maps `EST`→New York, so an `EST` input in July converts using EDT. The echoed offset reveals it, but the spec never states that abbreviations are DST-naive labels, not fixed offsets. |

---

## 7. Adversarial and weird

| Input | Expected behavior | Notes |
|---|---|---|
| (empty) | P1 | |
| `12pm` | P2 or P3 | **Spec gap** — both source and target are missing and no conjunction exists. P3's trigger says "no conjunction found", P2's says "missing source". Precedence undefined, and P3's text (`Convert {time} {source} to where?`) has no `{source}` to interpolate. |
| `12pm in` | P2 or P3 | Same gap, conjunction present but both sides empty. |
| `12pm in London` | P2 | Spec states this explicitly: never assume the device zone. |
| `12pm ET in` | P3 | Empty target. |
| `12pm ET` | P3 | No conjunction. |
| `London` | P1 | Lone zone, no time — P1 wins over P2/P3. |
| `ET` | P1 | |
| `in London` | P1 | |
| `ET in London` | P1 | Zones on both sides, no time. P1's "start with a time" wording fits well here. |
| `London to Tokyo` | P1 | Same, and probably common. |
| `in` | P1 | |
| `ET 12pm in London` | P1 | **Time at the end of the source side.** The time must match at position 0, so this is P1 even though every piece of information is present. Plausible phrasing; worth a decision. |
| `12pm ET in London 3pm` | P5 | Trailing time poisons the target. |
| `12pm 3pm ET in London` | P5 | Two times; the second joins the source → `3pm et`. |
| `12pm ET in London in Tokyo` | P5 | Target `london in tokyo` — first-match scan keeps everything after the first conjunction. **Spec gap** on trailing extras. |
| `12pm ET in London'; DROP TABLE zones;--` | P5 | Injection-shaped; should just be an unknown token. |
| `<script>alert(1)</script>` | P1 | Confirm the echo line escapes it. |
| `🕐 12pm ET in London` | P1 | Leading emoji blocks the time match. |
| `12pm ET in 🇬🇧` | P5 | Flag emoji as a zone. Consider an alias for fun, low priority. |
| `12pm ET in London 😀` | P5 | Trailing emoji. Same family as trailing punctuation. |
| `123456` | P1 | Numbers only. |
| `24:00 ET in London` | P1 | Hours are 0–23. Users may expect end-of-day. |
| `13:00 pm ET in London` | P5 | Time matches `13:00` as 24h, then `pm` joins the source → `pm et`. **Spec gap** — a 12-hour hour out of range (`13pm`, `25pm`) isn't rejected, it's silently re-read as 24h plus garbage. |
| `9am ET in Llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch` | P5 | Long single token; check prompt layout doesn't break. |
| 2,000-character repeated string | P1 or P5 | **Spec gap** — no input length cap. Check resolver performance and UI truncation. |
| `12pm` + NUL byte + `ET in London` | **spec gap** | Control characters aren't covered by "collapse whitespace". |

---

## Recommendations

### Conjunction list — suggested additions

Add (low risk, high frequency):

1. `at`
2. `into`
3. `for`
4. `vs`, `versus`
5. `→`, `->`, `=>`
6. `=` (normalize runs, so `==` works)
7. `/` and `|` (spaced only)
8. `,` (requires punctuation stripping first)
9. `-` and `—` (**spaced only**, to protect `2-3pm` and `Port-au-Prince`)

Reject: `as`, `then`, `becomes`, `equals`, `when it's`, and any phrasing that
inverts direction (`what time in X when it's Y`).

Also recommend, as separate normalization steps rather than conjunction entries:

- Strip leading filler before the time: `from`, `convert`, `what is`, `what's`, `whats`.
- Strip a leading conjunction from each side token (fixes `in to`, `in in`, `to to`).
- Strip trailing `time` / `local time` / `local` from the target.
- Strip trailing/surrounding punctuation and emoji before resolving zones.
- Decide on `noon` / `midnight` / `midday` as named times.

### Cases most likely to expose spec gaps

1. **`06:34 Portugal in PST`** — the spec's own "must parse" example conflicts with
   its own ">1 candidate → always prompt" rule. Pick one.
2. **Legacy tz-db identifiers** (`Portugal`, `Japan`, `Turkey`, `GB`, `US/Pacific`,
   `Zulu`) — resolver 3 runs before the country table, so multi-zone countries can
   silently bypass P4. Decide whether to filter `knownTimeZoneIdentifiers`.
3. **`7:30 New York in London`** — a bare `H:mm` in the 1–12 range parses as 24h
   with no warning. Most likely silent-wrong-answer in the whole app.
4. **`9am ET London`** (conjunction omitted) — currently P3, but probably the most
   common natural phrasing after `in`. Needs a zone-boundary split strategy.
5. **Prompt precedence** — `12pm` (P2 vs P3), `9am CST to IST` (two P4s),
   `12pm CST in Lodnon` (P4 vs P5). The spec defines triggers but no ordering, and
   P2/P3's templates assume fields that may be empty.
6. **Trailing punctuation** (`12pm ET in London?`) — produces a confusing P5 for an
   otherwise perfect input. One-line fix, high frequency.
7. **`9am to 5pm ET in London`** — a range yields P2 ("Where is 9:00 am?"), which
   reads as a non-sequitur. Detect ranges and say so.
8. **`13:00 pm ET in London`** — an out-of-range 12-hour time degrades into 24h plus
   a junk source token instead of being rejected.
9. **`ET 12pm in London`** — all information present, time not at position 0 → P1.
   Decide whether a time anywhere in the source side is acceptable.
10. **Time-adjacent junk swallowed into the source** (`12pmm`, `12:300`, `2pm-3pm`) —
    a partial time match leaves debris that turns into a misleading P5. Consider
    requiring a word boundary after the time match.
