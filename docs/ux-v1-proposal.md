# UX v1 Revision Proposal — Time Converter 3000

Drafted 2026-10-21 for Olivier's review. Scope: limited, restrained v1
improvements. Not sized or prioritized — a separate session will t-shirt size
accepted items into the backlog.

## Current state

One text field, live parse per keystroke; results echo as
`12:00 pm New York (UTC-4) → 5:00 pm London (UTC+1)` with a tz-identifier
detail line; every prompt (P1–P5) is a single red text line and the only
recovery is retyping. Access is "find and open the app" on all three platforms.

## Guiding rule

**The typed sentence is the single source of truth, on every platform.** All
proposed interactions *edit the sentence* rather than introduce parallel state.
Type a sentence → read a conversion → fix mistakes by tapping things that
rewrite the sentence. Identical on iPhone, iPad, and Mac.

## Proposed v1 changes

### Corrections & ambiguities

1. **Tappable candidate chips for P4 (ambiguous zone).**
   *What:* render `Prompt.ambiguousZone`'s `[ZoneChoice]` (already carries
   identifier, representative city, live UTC offset) as a row of buttons under
   the message: `Chicago −5` `Shanghai +8` …. Tapping replaces the ambiguous
   token in the input string, in place (`9am CST to IST` + tap Chicago →
   `9am Chicago to IST`), which re-parses naturally and moves straight to the
   *next* prompt if any.
   *Why:* ambiguity is the designed-in prompt (countries, CST/IST); making the
   user retype a city they can see is the worst friction in the app.
   *Consistency:* same SwiftUI buttons, tap on iOS = click on Mac; the sentence
   stays the state. No forked model.

2. **"Did you mean…" chips for P5 (unknown token).**
   *What:* on `unknownZone`, run the token through a small edit-distance pass
   (≤2) over the names the resolver chain can already see (aliases, tz-db
   cities, countries, fallback gazetteer) and offer the top ≤3 as chips —
   `Lodnon` → `London?`. Same tap-to-replace mechanics as #1; zero new UI
   concepts.
   *Why:* the QA list's verdict is that fast-typing typos are a top failure
   mode; this converts the most common dead end into one tap. Resolver change
   is additive (a suggestions method beside `resolve`), parser stays pure.
   *Consistency:* identical everywhere.

3. **Prompt tone & styling: guidance, not failure.**
   *What:* prompts stop being red. One calm secondary-colored line with an
   SF Symbol (`questionmark.circle` for P2–P4, `character.cursor.ibeam` for
   P1/P5), message copy trimmed to the action ("Where is 12:00 pm? Add a place
   before 'in'"). Red is reserved for nothing in v1 — the app has no true
   errors.
   *Why:* mid-typing, the user sees prompts constantly (every keystroke until
   the sentence completes); red screams at normal typing.
   *Consistency:* identical everywhere. Cheap: copy + one view change.

4. **Mid-typing quiet period.**
   *What:* while the field is focused and the input doesn't yet parse, show the
   prompt only after a short pause (~600 ms debounce on *prompt display only* —
   results still render instantly). Alternative flavor: suppress P2/P3 until
   the user has typed a conjunction or pressed return.
   *Why:* today every half-typed sentence flashes a prompt per keystroke; this
   is the single biggest calm-ness win and costs ~10 lines in the view layer.
   *Consistency:* identical everywhere.

### Access

5. **iOS/iPad: autofocus the input on foreground.**
   *What:* `@FocusState` the field on appear/foreground, keyboard up
   immediately.
   *Why:* for a typed-input tool, launch-to-typing latency *is* the access
   story; everything else is a launcher in front of this.

6. **iOS: Control Center control + App Shortcut (launchers, honest ones).**
   *What:* an iOS 18+ `ControlWidget` button ("Convert a time") and an App
   Shortcut phrase, both deep-linking into the app with the field focused (#5).
   Reachable from Control Center and lock screen without home-screen real
   estate.
   *Why — and what we're NOT claiming:* no widget can accept typed input;
   home-screen/lock-screen *display* widgets would just be decorative clocks
   for us, so they're parked. The control is purely a faster path to the
   keyboard, which is the honest best iOS can do for this app.
   *Consistency:* launcher only; interaction model untouched.

7. **Mac: menu-bar presence with a global hotkey** — see decision below.

## The Mac access-path decision

Olivier wants a top-bar daemon + keystroke. Facts first (verified):
**MenuBarExtra is not available to Mac Catalyst** — it's a SwiftUI scene for
native macOS targets only. What Catalyst *can* do is the established
loadable-AppKit-bundle pattern: a small bundle built against the macOS SDK,
loaded at runtime, with full AppKit access — `NSStatusItem` for the menu-bar
icon and Carbon `RegisterEventHotKey` for a system-wide hotkey (no
accessibility permission needed). None of the musicLibrary apps have done this;
it's new ground but a well-documented pattern.

| Option | Verdict |
|---|---|
| **A. AppKit bundle inside the existing Catalyst app** — NSStatusItem + global hotkey that activates the app and focuses the field | **Recommended.** One target, one codebase, TestFlight-on-Mac keeps working, ~150–250 lines of bridge code. The summoned thing is the normal app window (v1), not a floating panel. |
| B. Separate native menu-bar helper app | Forks the codebase and the shipping story; a second thing to sign and update. Not v1. |
| C. Migrate Mac to a native SwiftUI target (`MenuBarExtra` proper) | The "right" long-term shape if the Mac side grows, but it abandons Catalyst — and with it the Mac-via-iOS-TestFlight distribution we rely on. Parked. |

*Consistency implication of A:* the hotkey/menu-bar item is a Mac-only
*affordance*, but what it summons is the identical app and interaction model.
Equivalent in spirit to #6's Control Center control. Accepted asymmetry: access
differs per platform; usage never does.

## Deliberately not now (v2+)

- Remembering ambiguity picks across inputs (session or persistent "CST means
  Chicago") — wants a settings/undo story first.
- Tappable echo line to flip a resolved zone after the fact — redundant once
  chips exist; adds a hidden interaction.
- Floating Spotlight-style Mac panel instead of the app window.
- Conversion history / pinned pairs; display widgets showing favorite pairs.
- Siri natural-language conversion (App Intent with a sentence parameter) —
  genuinely input-capable but its error/prompt flow can't match the app's;
  revisit when prompts are stable.
- Parser-side conjunction/punctuation growth — already backlog item 6, not UX.

## Open questions for Olivier

1. **Mid-typing prompts (#4):** debounce flavor or suppress-until-conjunction
   flavor? (Debounce is my recommendation — simpler and language-agnostic.)
2. **Mac hotkey default:** proposal is ⌃⌥Space (unclaimed by system defaults) —
   happy with that, or prefer something else from day one?
3. **Did-you-mean auto-accept:** when exactly one candidate is within edit
   distance 1 (e.g. `Lodnon`), should the parser silently accept it and show
   "assuming London" in the echo, or always require the tap? (Proposal: always
   require the tap in v1 — silent correction risks wrong-city conversions that
   look right.)

---
*Sources for the Catalyst menu-bar facts:*
[Standalone Status Menu in a Mac Catalyst App](https://blog.overdesigned.net/posts/2021-08-26-catalyst-status-menu/) ·
[Beyond the Checkbox with Catalyst and AppKit](https://www.highcaffeinecontent.com/blog/20190607-Beyond-the-Checkbox-with-Catalyst-and-AppKit) ·
[macOS Menu Bar App Guide (2026)](https://techconcepts.org/blog/macos-menu-bar-guide)

---

## Decisions (Olivier, 2026-10-21)

- **Accepted**: tappable-chip corrections (P4 + did-you-mean unified); autofocus-on-launch; home screen and Control Center launchers; Mac menu-bar via loadable AppKit bundle.
- **Widgets**: dropped — agreed decorative.
- **Debounce**: yes, ~600 ms.
- **Mac global hotkey**: **⌃⌥T** ("T for time"), not ⌃⌥Space.
- **One-letter-off typos**: never auto-accept — always require the tap.
- **Explicitly out, not even backlogged**: remembering time zones, visualising zones against each other, converting to multiple target zones at once. A world exists where these happen; it is not this world yet.
