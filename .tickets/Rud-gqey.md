---
id: Rud-gqey
status: open
deps: []
links: []
created: 2026-07-11T07:04:51Z
type: epic
priority: 2
assignee: Leon Georgi
tags: [needs-approval, tests, ui-tests, ci, quality-gates]
---
# Deterministische UI-Tests und automatisierte Qualitäts-Gates etablieren

Die generischen UI-Test-Templates durch wenige robuste Nutzerreisen ersetzen und schnelle sowie vollständige Testsuiten über Testpläne und CI klar ausführbar machen.

## Design

UI-Tests nutzen feste lokale Daten, stabile Accessibility-Identifier und deaktivierte externe Systeme. Fast- und Full-Suite getrennt halten; visuelle Snapshot-Tests nicht flächendeckend einführen.

## Acceptance Criteria

Kritische iOS-Nutzerreisen laufen deterministisch; die unterstützte macOS-App besitzt mindestens einen sinnvollen Smoke-Test; Fast- und Full-Suite sind lokal und in CI eindeutig ausführbar; die Child-Tickets dieses Epics sind abgeschlossen.
