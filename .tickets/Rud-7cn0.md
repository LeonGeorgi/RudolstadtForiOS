---
id: Rud-7cn0
status: closed
deps: [Rud-e1lc]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-5hbr
tags: [approved, tests, testability, festival-profile, cloudkit, persistence, effort-large, confidence-medium]
---
# FestivalProfileStore in testbare Profil-, Persistenz- und Sync-Verantwortungen trennen

Die lokale Profilmutation, Cache-Persistenz und CloudKit-Synchronisation des FestivalProfileStore so abgrenzen, dass Fachregeln und Sync-Zustandsübergänge ohne echte iCloud-Umgebung geprüft werden können.

## Design

Reine Profilmutation und Normalisierung von Systemadaptern trennen; Persistenz und Cloud-Sync hinter kleinen Schnittstellen kapseln; CloudKit-Record-Mapping und Zustandsübergänge separat testbar machen. CKSyncEngine selbst nicht nachimplementieren.

## Acceptance Criteria

Lokale Profiländerungen benötigen in Tests kein CloudKit; Persistenz kann unmittelbar und ohne reale Sleep-Wartezeiten beobachtet werden; Sync-Mapping und Konfliktregeln sind separat aufrufbar; das öffentliche Verhalten des Stores und die iOS-Sharing-Funktionen bleiben erhalten.

## Notes

**2026-07-11T08:30:01Z**

Implementiert: FestivalProfileReducer kapselt lokale Mutation und Normalisierung; FestivalProfilePersisting kapselt Cache-/Legacy-Laden und Speichern, mit injizierbarer Verzögerung und flushPendingPersistence für unmittelbar beobachtbare Tests; der CKContainer wird bei deaktiviertem CloudKit nicht mehr erzeugt. FestivalProfileSyncPlanner, FestivalProfileCloudRecordMapper und FestivalProfileSyncConflictPolicy machen Sync-Planung, Record-Mapping und Konfliktentscheidungen ohne CKSyncEngine separat aufrufbar. Vier fokussierte Tests ergänzt (FestivalProfileStoreTests jetzt 9 Tests). Verifikation: plutil und git diff --check erfolgreich. Gezielter Lauf auf iPhone 17e, iOS 26.5, in sauberer HEAD-Kopie plus ausschließlich Rud-7cn0-Dateien: 9/9 Tests bestanden. Im eigentlichen Arbeitsbaum verhindert eine unabhängige unvollständige FriendsView-Änderung (ShapeStyle.rudolstadt) den Testhost-Build; ein anschließender isolierter Wiederholungslauf kompilierte die finale Mapper-Änderung erfolgreich, hing aber beim Simulator-Teststart und wurde nach 129 s abgebrochen.
