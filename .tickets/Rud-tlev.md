---
id: Rud-tlev
status: open
deps: [Rud-3kry]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 0
assignee: Leon Georgi
parent: Rud-sa0w
tags: [needs-approval, tests, data-store, cache, fallback, concurrency, effort-large, confidence-high]
---
# Festivaldaten-Cache, Fallbacks und konkurrierende Refreshes testen

Die vollständige Zustandsmatrix beim Laden und Aktualisieren der Festivaldaten einschließlich Fehlern und konkurrierenden Refreshes automatisiert prüfen.

## Design

Frischen, veralteten, fehlenden und unlesbaren Cache mit erfolgreichem oder fehlerhaftem Download kombinieren. Bundle-Backup, vorhandene sichtbare Daten, Download-Metadaten und Generation beziehungsweise Cancellation kontrolliert beobachten.

## Acceptance Criteria

Alle Cache- und Netzwerk-Kombinationen liefern den vorgesehenen LoadingEntity- und Fallback-Zustand; vorhandene sichtbare Daten gehen bei Fehlern nicht verloren; Metadaten und Backup-Flags stimmen; überholte konkurrierende Ergebnisse überschreiben keinen neueren Zustand.
