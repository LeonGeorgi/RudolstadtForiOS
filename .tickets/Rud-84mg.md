---
id: Rud-84mg
status: closed
deps: [Rud-7cn0]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 0
assignee: Leon Georgi
parent: Rud-sa0w
tags: [approved, tests, festival-profile, migration, persistence, cloudkit, regression, effort-large, confidence-medium]
---
# Festivalprofil-Migration, Persistenz und Sync-Regeln absichern

Lokale Profilregeln, alte UserDefaults-Migration, Cache-Roundtrips und die extrahierten CloudKit-Mapping- und Konfliktregeln umfassend testen.

## Design

Isolierte UserDefaults-Suites und kontrollierte Repository- beziehungsweise Sync-Adapter verwenden. Saved Events, Ratings, Icons, Notes, Badges, Freundprofile, Löschungen und Remote-Konflikte als beobachtbare Zustandsübergänge testen. Den lokalen Profilcache einschließlich CloudKit-Sync-Zustand pro Festivaljahr speichern. Den bisherigen jahresunabhängigen Cache einmalig, verlustfrei und idempotent dem in ihm gespeicherten Festivaljahr zuordnen; ein Cache eines anderen Jahres darf beim Start des aktuellen Festivals nicht geladen werden.

## Acceptance Criteria

Legacy-Daten werden vollständig und idempotent migriert; lokale Änderungen persistieren und laden verlustfrei; leere Werte löschen korrekt; Listener feuern nur bei relevanten Änderungen; Remote-Updates, Löschungen und Konfliktregeln erzeugen die erwarteten Profil- und Sync-Zustände. Profilcache, Freundprofile, Share-Daten und CloudKit-Sync-Zustände verschiedener Festivaljahre sind vollständig isoliert. Der bisherige jahresunabhängige Cache wird dem darin gespeicherten Festivaljahr zugeordnet, ohne einen bereits gültigen Jahrescache zu überschreiben, und erst nach erfolgreicher Übernahme entfernt.

## Notes

**2026-07-12T15:58:54Z**

Vom Nutzer freigegeben und begonnen. Ticket um jahresbezogene Cache-Isolation erweitert. Implementiert: Cache-Schlüssel pro Festivaljahr, injizierbares Festivaljahr in der UserDefaults-Persistenz, konservative/idempotente Übernahme von festival-profile-cache-v1 anhand des eingebetteten Jahres, Schutz vor falschem Jahrescache sowie fünf fokussierte Regressionstests für Isolation, Migration, bestehenden Zielcache, falsches Jahr und beschädigtes Ziel. Statisch verifiziert: git diff --check und plutil erfolgreich. Kein Build oder Testlauf ausgeführt, da dafür keine ausdrückliche Freigabe vorliegt.

**2026-07-12T16:01:26Z**

Gezielte Laufzeitverifikation nach Nutzerfreigabe: FestivalProfilePersistenceTests auf iPhone 17e / iOS 26.5 ausgeführt. Alle 5 Tests in 1 Suite bestanden (Swift-Testing-Zeit 0,014 s; xcodebuild gesamt 53,473 s). Produktions- und Testtarget kompilierten erfolgreich. Die vollständige Testsuite wurde nicht ausgeführt.

**2026-07-12T16:05:38Z**

Vom Nutzer nach erfolgreichem gezieltem Test zur Fertigstellung und zum Commit freigegeben.
