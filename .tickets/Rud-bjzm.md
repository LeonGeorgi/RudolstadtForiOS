---
id: Rud-bjzm
status: closed
deps: []
links: []
created: 2026-07-16T03:10:56Z
type: bug
priority: 1
assignee: Leon Georgi
tags: [approved, artist-detail, notes, data-loss, ios26, effort-small, confidence-high]
---
# Künstlernotiz: vorhandenen Text vor dem Bearbeiten laden

Beim Öffnen des Notizeditors bleibt noteText im aktuellen ArtistDetailView auf seinem Initialwert. Eine vorhandene Notiz erscheint dadurch leer und kann beim Speichern unbeabsichtigt überschrieben werden.

## Design

Den Editor über einen einzigen Präsentationspfad öffnen, der noteText unmittelbar aus dem FestivalProfileStore übernimmt. Den vorhandenen Abbruchschutz erhalten und den Sheet-Container auf das aktuelle NavigationStack-Muster abstimmen. Keine Änderung am Notizmodell oder CloudKit-Sync.

## Acceptance Criteria

Eine bestehende Notiz erscheint vollständig im Editor; Abbrechen ohne Änderung schließt direkt; Abbrechen nach Änderung warnt; Speichern aktualisiert; Leeren entfernt die Notiz; erneutes Öffnen zeigt den aktuellen Stand. Gezielte Tests decken vorhandene, neue und gelöschte Notizen ab.

## Notes

**2026-07-16T03:29:00Z**

Umgesetzt: Beide Öffnungspfade laden den aktuellen Store-Wert über presentNoteEditor in einen ArtistNoteDraft; Abbruchschutz vergleicht mit dem beim Öffnen geladenen Original; Sheet nutzt NavigationStack. Drei Regressionstests für bestehende, neue und gelöschte Notizen ergänzt. Verifikation: betroffene Dateien bestehen git diff --check; App und Test-Bundle kompilierten beim gezielten xcodebuild-Test. Testausführung auf My Mac (Designed for iPhone/iPad) blieb aus, weil der Test-Host vor dem Bootstrap mit signal kill beendet wurde. Simulator-/UI-Verifikation nicht ausgeführt.
