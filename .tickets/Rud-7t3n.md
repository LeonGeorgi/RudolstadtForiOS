---
id: Rud-7t3n
status: open
deps: [Rud-lmlj]
links: []
created: 2026-07-11T07:04:53Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-gqey
tags: [needs-approval, tests, ui-tests, macos, localization, accessibility, effort-medium, confidence-medium]
---
# macOS-Smoke-Test und relevante Darstellungs-Konfigurationen ergänzen

Für die unterstützte macOS-App einen sinnvollen Launch-Smoke-Test etablieren und ausgewählte UI-Smokes unter relevanten Sprach- und Accessibility-Konfigurationen ausführen.

## Design

Den macOS-Test auf Start, Hauptnavigation und lokale Festivaldaten begrenzen. Für iOS gezielt Deutsch und Englisch sowie mindestens eine große Dynamic-Type-Konfiguration testen; Dark Mode nur dort aufnehmen, wo eine semantische Assertion möglich ist.

## Acceptance Criteria

Der macOS-Smoke-Test enthält fachliche Assertions statt nur eines Screenshots; ausgewählte iOS-Smokes laufen auf Deutsch und Englisch sowie mit großer Textgröße; Tests verwenden keine pixelgenauen Layoutannahmen; überflüssige Launch-Performance-Templates sind entfernt oder begründet ersetzt.
