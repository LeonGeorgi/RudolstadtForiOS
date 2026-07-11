---
id: Rud-bwgp
status: closed
deps: []
links: []
created: 2026-07-11T04:19:22Z
type: task
priority: 2
assignee: Leon Georgi
tags: [approved]
---
# Deterministic App Store screenshot pipeline

## Notes

**2026-07-11T04:20:42Z**

Approved by user; implementation started.

**2026-07-11T04:30:50Z**

Implemented deterministic bundled-data screenshot mode, disabled CloudKit/network refreshes, seeded stable UI state, added accessibility identifiers, added six independent Maestro flows and capture runner, and removed the legacy XCTest screenshot pipeline. Static checks passed: Maestro syntax, bash syntax, pbxproj plist, scheme XML, and git diff whitespace. Build/run not performed per AGENTS.md.

**2026-07-11T04:31:40Z**

User explicitly requested full build and screenshot pipeline runtime verification.

**2026-07-11T04:54:51Z**

Full runtime verification passed on iPhone 17e / iOS 26.5: successful signed build and 12 screenshots (6 German + 6 English, light mode), all 1170x2532 with fixed 09:41 status bar. Runtime fixes: localized Saturday/News selectors, news scroll centering above floating tab bar, deterministic schedule-tab/navigation reset.

**2026-07-11T04:59:47Z**

Follow-up: artist detail screenshot may capture before async background color extraction completes.

**2026-07-11T05:05:41Z**

Artist detail follow-up fixed: ArtistDetailView now exposes a theme-ready accessibility state only after cached/extracted colors are applied; screenshot mode applies them without transition animation. Maestro waits for artist-detail-216-theme-ready. Full de/en light pipeline passed on iPhone 17e (iOS 26.5), and both generated detail screenshots were visually checked.

**2026-07-11T05:14:14Z**

User approved follow-up: replace the obsolete GitHub Actions XCTest workflow with the Maestro screenshot runner and artifact upload. Remote artist images and map tiles are explicitly out of scope and tracked separately.

**2026-07-11T05:16:03Z**

Replaced obsolete GitHub XCTest workflow with a manual macos-26 Maestro workflow: pinned Java/Maestro setup, dynamic iOS 26 iPhone selection, shared capture runner, screenshot artifact upload, failure diagnostics, and run summary. Updated README. Validation passed for YAML parsing, bash syntax, whitespace, and simulator-selection logic against installed devices. Actual GitHub-hosted execution requires commit/push and manual dispatch.

**2026-07-11T06:04:24Z**

User approved CI robustness follow-up after run 29141337716: add stable accessibility identifiers for tab and map/list navigation, then update Maestro flows to use identifiers instead of localized text.

**2026-07-11T06:06:27Z**

CI navigation fix implemented after run 29141337716: added stable IDs for all app tabs, the locations map/list toggle, and the news toolbar button; updated five Maestro flows to use IDs instead of localized navigation text. All six flow YAML files parse, identifier references match source, and git diff whitespace check passes. Build/runtime verification not run because it was not explicitly requested.

**2026-07-11T06:49:15Z**

User approved the follow-up based on run 29142506630: remove ineffective identifiers inside SwiftUI tabItem labels and target the native SF Symbol resource IDs exposed by the CI accessibility hierarchy.

**2026-07-11T06:49:51Z**

Fixed run 29142506630 failure using the captured CI accessibility hierarchy: removed five tabItem accessibility identifiers that SwiftUI did not propagate to UITabBarButton, and changed locations/artist flows to exact escaped native resource IDs map.fill and theatermasks.fill. All six YAML flows parse, selectors resolve to the intended regex strings, and git diff whitespace passes. No build/runtime run performed.
