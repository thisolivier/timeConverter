# Releases

One row per shipped build per lane, appended by the ship scripts
(`scripts/lib/parity-gate.sh` `record_release`). `commit` is the code that
shipped; the lane-drift report compares it with HEAD over the shared core
(`TimeConverterCore/Sources`, `fixtures/conversion-cases.json`) to say which
lanes are behind. Build numbers are shared across lanes via `project.yml`.

Rule: **a core change ships to all three lanes** at the same build number.
iOS and Mac go through `scripts/ship.sh` and `scripts/ship-mac.sh` to
TestFlight; Android goes through `scripts/ship-android.sh` to GitHub Releases
(and from there to Obtainium on the phone).

| date | lane | build | version | commit | artifact |
|------|------|-------|---------|--------|----------|
| 2026-10-28 | ios | 15 | 0.1.0 | 899057c | TestFlight iOS (compact times, Antarctica, 309 cities, iOS-origin zone names) |
| 2026-10-28 | mac | 16 | 0.1.0 | 899057c | TestFlight macOS (same core as iOS 15) |
| 2026-10-28 | android | 17 | 0.1.0 | fdb0b98 | GitHub release android-0.1.0.17 (first signed APK; interim parser, pre-24b) |
| 2026-10-28 | android | 18 | 0.1.0 | 6c45a61 | GitHub release android-0.1.0.18 |
