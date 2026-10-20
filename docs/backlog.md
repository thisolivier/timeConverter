# TimeConvertor Backlog

Working structure: this file is the backlog and plan of record. Each item gets a short spec in `docs/` when it needs one (item 2 will get `docs/input-parsing-spec.md`). Stable decisions and findings land in docs; code lands via small commits after each major change.

## Items

- [x] **0. Bootstrap** — copy and adapt the nakedClaude `.claude` template, prune skills, git init, working structure. *(this session)*
- [x] **1. Dev environment** — universal macOS/iOS SwiftUI app building and running from the command line. Borrow proven setup (project generation, build/run scripts) from `../musicLibrary/iOSnative/` (Amperfy, SoulseekNavi, Navi Admin) — read access only. *(this session)*
- [x] **2. Input parsing spec** — dedicated session to specify exactly how freeform input strings ("12pm ET in London", "06:34 Portugal in PST") are broken down, and what disambiguation prompts to offer the user.
- [x] **3. Parser implementation** — implement `docs/input-parsing-spec.md`, with tests.
- [x] **4. Conversion UI** — single input field, parsed interpretation shown back to the user, converted result, disambiguation prompts.
- [ ] **5. TestFlight setup** — first upload via the `testflight-setup` skill; per-app portal setup, Release signing, ship script. *(in progress 2026-10-20)*
- [ ] **6. QA-candidates review** — work through `docs/qa-input-candidates.md` (reviewed by Olivier 2026-10-20: core pass-cases agreed; fun edge cases identified, especially punctuation). Likely incremental: Olivier may ask for autonomous low-hanging-fruit passes picking easy wins from the list (conjunction-list growth, punctuation tolerance) — each pass updates the spec first, then parser + tests.
