---
id: Rud-8z2c
status: closed
deps: []
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-5hbr
tags: [approved, tests, swift-testing, refactor, effort-medium, confidence-high]
---
# Bestehende Unit-Tests strukturieren und auf Swift Testing migrieren

Die thematisch gemischte DataConverterTests.swift in fokussierte Testdateien und wiederverwendbaren Test-Support aufteilen und die Unit-Tests schrittweise von XCTest auf Swift Testing übertragen.

## Design

Ordner nach Domain, Parsing, Services, Persistence, AppState und Support anlegen. Bestehende Szenarien unverändert erhalten; gemeinsame Artist-, Stage-, Event- und Datums-Fixtures zentralisieren. XCTest nur dort behalten, wo dessen APIs benötigt werden.

## Acceptance Criteria

Alle 43 bestehenden Unit-Test-Szenarien sind erhalten; keine einzelne Testdatei bündelt fachfremde Suites; neue gemeinsame Fixtures vermeiden relevante Duplikation; Unit-Tests verwenden überwiegend Swift Testing und bleiben im gemeinsamen Scheme ausführbar.

## Notes

**2026-07-11T07:20:43Z**

Implemented the approved test-suite reorganization: replaced the 1,136-line mixed XCTest file with ten focused Swift Testing suites under AppState, Domain, Notifications, Parsing, Persistence, and Services, plus centralized TestFixtures and TestDoubles support. Preserved all 43 working-tree scenarios, including the one scenario not yet present in HEAD. Updated the Unit Tests target and shared scheme membership to compile all 12 new files and removed the old monolith. Static verification passed: 43 @Test declarations, 12 target source entries, 12 file references, valid project.pbxproj, no XCTest remnants in Unit Tests, no trailing whitespace, and git diff whitespace check. Build/test execution was not run per AGENTS.md.

**2026-07-11T07:30:57Z**

Runtime verification explicitly requested by the user. The first cold run exposed a missing @MainActor annotation in NotificationPermissionPresentationTests and a future Swift 6 warning from Thread.isMainThread; both were fixed. A subsequent run exposed that RecommendationDataStoreTests depended on an empty simulator cache, so the test now arranges festivalData = .loading explicitly. After restarting the same simulator once to recover from an unrelated XCTest host bootstrap crash, both final measurements passed on iPhone 17e / iOS 26.5: warm/incremental run 23.20 s total with 43 tests in 10 suites passing in 0.201 s; clean DerivedData cold run 45.74 s total with the Swift Testing phase passing in 0.177 s. The cold Xcode test-operation phase reported 11.955 s; most wall time is host app, dependencies, signing, and simulator overhead.
