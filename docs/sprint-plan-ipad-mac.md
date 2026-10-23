# Sprint plan: iPad + Mac glass designs (item 20)

Written 2026-10-23 against `docs/design/Time Converter-selection.pdf` (4 pages)
and `Time Converter-2.html`. Olivier's direction: the HTML's paper-style Mac
variant is REDUNDANT — implement the **glass/native** style (PDF page 3) on
Mac. Order of work (Olivier's): shared elements first → Mac → iPad after Mac
is verified.

## What the designs say

- **Page 1**: iPhone portrait poster — current app, unchanged reference.
- **Page 2**: iPad/landscape **paper** poster: title top-left, TIME & PLACES
  input box top-right; below a full-width rule, side-by-side
  `FROM / LISBON / 8:00 PM / UTC+1` → rust right-arrow → `TO / SÃO PAULO /
  4:00 PM / UTC−3`; bottom rule; footer **"São Paulo is 4 hours behind
  Lisbon."** (target-named — new wording).
- **Page 3**: **Mac glass**: frosted translucent panel over the desktop;
  mono input line at top ("8pm Lisbon in São Paulo"), hairline rule, the same
  side-by-side FROM/TO pair (ink type on glass), smaller gray arrow, UTC±n
  small labels, target-named footer. No paper, no cream — system material.
- **Page 4**: iPad **keyboard-up compact**: input box full-width top; FROM/TO
  pair side by side; the rust arrow grows a label underneath — "4 hours
  behind" in rust; system keyboard occupies the bottom (370pt placeholder).

## Phases

### A. Shared conversion-pair UI (foundation)
Extract a platform-shared SwiftUI layer so Mac and iPad consume identical
components. Proposal: a second library product in the TimeConverterCore
package — `TimeConverterUI` — holding: design tokens (paper + glass palettes,
rust, typography scale incl. compressed-display helpers), `ConversionPairView`
(FROM/TO columns: label, place, big time + meridiem, sub-line), the arrow
(right-pointing variant + labeled variant), letterspaced label style, footer
text style. Core stays UI-free; the iPhone poster adopts shared pieces only
where zero-regression-trivial. The display model already carries source/target
split fields; the pair view needs source clock digits/meridiem split the way
the target already is (small core addition + tests).

### B. Mac glass (build after A, verify before C)
Replace the placeholder panel + MenuBarExtra dropdown content with the glass
design: system material background (ultraThin/hud-style), the shared pair
view, input top, prompts/chips restyled for glass legibility (light+dark).
Panel proportions per page 3 (wide, roughly 3:2). Keep: summon/focus behavior,
Quit, hotkey. Ship Mac build 11; Olivier verifies the glass on-device.

### C. iPad (after B verified)
Size-class-driven layout in the iOS app: iPhone keeps the current vertical
poster; iPad regular-width gets page 2 (paper, title left / input right,
side-by-side pair) and page 4 when the keyboard is up (compact pair + labeled
arrow). Reuses the A components. Ship iOS build (12).

## Open questions for Olivier (answers can land next session)

1. **UTC labels**: pages 2–4 show `UTC+1` / `UTC−3` under each time — but item
   21 (agreed 2026-10-23) just removed UTC from the iPhone in favor of
   zone-name/cities sub-lines. Do the new designs' UTC labels predate that
   decision (→ apply item-21 sub-lines on iPad/Mac too, consistent), or do
   iPad/Mac deliberately keep UTC±n? **Working assumption until answered:
   item-21 semantics everywhere (no UTC), since that decision is newer.**
2. **Footer wording**: adopt the target-named sentence ("São Paulo is 4 hours
   behind Lisbon.") everywhere including iPhone, or iPad/Mac only? **Working
   assumption: everywhere — one sentence, one implementation.**
3. **Mac panel size/behavior**: fixed ~720×480-ish per the design, or
   user-resizable? And the MenuBarExtra dropdown — same glass pair content,
   presumably narrower? **Working assumption: fixed-size panel, dropdown gets
   the same content adapted to its width.**
4. **iPhone layout**: unchanged (page 1 = current app), side-by-side pair is
   iPad/Mac only. **Working assumption: yes, unchanged.**

## Mechanics

- Each phase = one Opus agent, gated on both test lanes + screenshot QA
  (Mac glass: screenshots blocked headlessly — build + launch + Olivier's
  eyes; iPad: simulator "iPad Pro 13-inch" screenshots, portrait + landscape
  + -forceCompact).
- Ship + push per sprint rule: B ends with Mac build 11, C with iOS build 12.
- The HTML (`Time Converter-2.html`) carries exact glass tokens (blur,
  opacity, shadows) — extract at phase-B start.
