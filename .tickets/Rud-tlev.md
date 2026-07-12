---
id: Rud-tlev
status: closed
deps: [Rud-3kry]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 0
assignee: Leon Georgi
parent: Rud-sa0w
tags: [approved, tests, data-store, cache, fallback, concurrency, effort-large, confidence-high]
---
# Festivaldaten-Cache, Fallbacks und konkurrierende Refreshes testen

Die vollständige Zustandsmatrix beim Laden und Aktualisieren der Festivaldaten einschließlich Fehlern und konkurrierenden Refreshes automatisiert prüfen.

## Design

Frischen, veralteten, fehlenden und unlesbaren Cache mit erfolgreichem oder fehlerhaftem Download kombinieren. Bundle-Backup, vorhandene sichtbare Daten, Download-Metadaten und Generation beziehungsweise Cancellation kontrolliert beobachten.

## Acceptance Criteria

Alle Cache- und Netzwerk-Kombinationen liefern den vorgesehenen LoadingEntity- und Fallback-Zustand; vorhandene sichtbare Daten gehen bei Fehlern nicht verloren; Metadaten und Backup-Flags stimmen; überholte konkurrierende Ergebnisse überschreiben keinen neueren Zustand.

## Notes

**2026-07-12T15:44:52Z**

Implementiert: FestivalDataStoreTests decken frischen, veralteten, fehlenden und unlesbaren Cache mit erfolgreichen und fehlerhaften Downloads, Bundle-Fallback, Erhalt sichtbarer Daten, Cache-Schreibfehler und Download-Metadaten ab. DataStore verwendet eine Refresh-Generation, damit überholte parallele Ergebnisse weder Zustand noch Cache überschreiben. Gezielte Verifikation auf iPhone 17e/iOS 26.5: FestivalDataStoreTests 13/13 bestanden; git diff --check erfolgreich. Keine vollständige Testsuite ausgeführt.
