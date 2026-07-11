---
id: Rud-8pt3
status: open
deps: [Rud-lmlj]
links: []
created: 2026-07-11T07:04:53Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-gqey
tags: [needs-approval, tests, ui-tests, ios, accessibility-identifiers, effort-large, confidence-high]
---
# Kritische iOS-Nutzerreisen als robuste UI-Tests umsetzen

Die generischen iOS-UI-Test-Templates durch wenige fachlich aussagekräftige End-to-End-Smoke-Tests für die wichtigsten Nutzerwege ersetzen.

## Design

Stabile Accessibility-Identifier und semantische Assertions verwenden. Mindestens App-Start, Schedule mit Speichern und Saved-Filter, Artist-Bewertung und Notiz, News-Lesestatus sowie Ortsliste beziehungsweise Bühne abdecken. Keine koordinatenbasierten Interaktionen.

## Acceptance Criteria

Die definierten Nutzerreisen prüfen sichtbare Zielzustände und persistierte Auswirkungen; jeder Test ist einzeln und in beliebiger Reihenfolge ausführbar; generische testExample- und Screenshot-Template-Tests sind entfernt; Flakiness durch Animationen oder Remote-Inhalte ist vermieden.
