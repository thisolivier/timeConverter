# TimeConvertor Backlog

Working structure: this file is the backlog and plan of record. Each item gets a short spec in `docs/` when it needs one (item 2 will get `docs/input-parsing-spec.md`). Stable decisions and findings land in docs; code lands via small commits after each major change.

## Items

- [x] **0. Bootstrap** — copy and adapt the nakedClaude `.claude` template, prune skills, git init, working structure. *(this session)*
- [x] **1. Dev environment** — universal macOS/iOS SwiftUI app building and running from the command line. Borrow proven setup (project generation, build/run scripts) from `../musicLibrary/iOSnative/` (Amperfy, SoulseekNavi, Navi Admin) — read access only. *(this session)*
- [x] **2. Input parsing spec** — dedicated session to specify exactly how freeform input strings ("12pm ET in London", "06:34 Portugal in PST") are broken down, and what disambiguation prompts to offer the user.
- [x] **3. Parser implementation** — implement `docs/input-parsing-spec.md`, with tests.
- [ ] **4. Conversion UI** — single input field, parsed interpretation shown back to the user, converted result, disambiguation prompts.
