---
id: Rud-84mg
status: open
deps: [Rud-7cn0]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 0
assignee: Leon Georgi
parent: Rud-sa0w
tags: [needs-approval, tests, festival-profile, migration, persistence, cloudkit, regression, effort-large, confidence-medium]
---
# Festivalprofil-Migration, Persistenz und Sync-Regeln absichern

Lokale Profilregeln, alte UserDefaults-Migration, Cache-Roundtrips und die extrahierten CloudKit-Mapping- und Konfliktregeln umfassend testen.

## Design

Isolierte UserDefaults-Suites und kontrollierte Repository- beziehungsweise Sync-Adapter verwenden. Saved Events, Ratings, Icons, Notes, Badges, Freundprofile, Löschungen und Remote-Konflikte als beobachtbare Zustandsübergänge testen.

## Acceptance Criteria

Legacy-Daten werden vollständig und idempotent migriert; lokale Änderungen persistieren und laden verlustfrei; leere Werte löschen korrekt; Listener feuern nur bei relevanten Änderungen; Remote-Updates, Löschungen und Konfliktregeln erzeugen die erwarteten Profil- und Sync-Zustände.
