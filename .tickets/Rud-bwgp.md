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
