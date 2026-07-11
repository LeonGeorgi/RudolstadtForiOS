---
id: Rud-7cn0
status: open
deps: [Rud-e1lc]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-5hbr
tags: [needs-approval, tests, testability, festival-profile, cloudkit, persistence, effort-large, confidence-medium]
---
# FestivalProfileStore in testbare Profil-, Persistenz- und Sync-Verantwortungen trennen

Die lokale Profilmutation, Cache-Persistenz und CloudKit-Synchronisation des FestivalProfileStore so abgrenzen, dass Fachregeln und Sync-Zustandsübergänge ohne echte iCloud-Umgebung geprüft werden können.

## Design

Reine Profilmutation und Normalisierung von Systemadaptern trennen; Persistenz und Cloud-Sync hinter kleinen Schnittstellen kapseln; CloudKit-Record-Mapping und Zustandsübergänge separat testbar machen. CKSyncEngine selbst nicht nachimplementieren.

## Acceptance Criteria

Lokale Profiländerungen benötigen in Tests kein CloudKit; Persistenz kann unmittelbar und ohne reale Sleep-Wartezeiten beobachtet werden; Sync-Mapping und Konfliktregeln sind separat aufrufbar; das öffentliche Verhalten des Stores und die iOS-Sharing-Funktionen bleiben erhalten.
