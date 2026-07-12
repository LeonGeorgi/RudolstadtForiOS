---
id: Rud-1k7h
status: closed
deps: [Rud-e1lc]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 0
assignee: Leon Georgi
parent: Rud-sa0w
tags: [approved, tests, schedule, recommendations, date-time, regression, effort-large, confidence-high]
---
# Programm-, Zeitkonflikt- und Empfehlungslogik umfassend absichern

Die zentrale Programm- und Empfehlungslogik mit Beispieltests, parametrisierten Grenzfällen und deterministisch erzeugten Invarianten absichern.

## Design

Event-Tageswechsel, Laufwege, Ankunftspuffer, Dauerabschätzung, Filter und RecommendationService gemeinsam betrachten. Für größere generierte Spielpläne feste Seeds verwenden und fachliche Invarianten statt konkreter Implementierungsdetails prüfen.

## Acceptance Criteria

Tests belegen: gespeicherte Events bleiben erhalten; Empfehlungen überschneiden sich nicht; pro Artist wird höchstens ein Event empfohlen; vergangene Events werden ausgeschlossen; Rating-Prioritäten und stabile Reihenfolge gelten; Mitternacht, Laufwege, Puffer und Dauergrenzen sind abgedeckt.

## Notes

**2026-07-12T15:30:46Z**

Implementierung ergänzt: 6 neue Regressionstests sichern gespeicherte Events, stabile Reihenfolge unabhängig von Eingabereihenfolge, Mitternachtszuordnung, Laufwege samt 2-Minuten-Ankunftspuffer und Dauergrenzen ab. Zusätzlich prüfen deterministisch erzeugte Spielpläne mit festen Seeds die Invarianten: nur zukünftige Empfehlungen, höchstens ein Event je Artist und keine zeitlichen/örtlichen Konflikte. Bestehende Filtertests decken saved, interesting, all und optimal bereits ab. Statisch verifiziert: git diff --check erfolgreich. Laufzeitverifikation der Unit Tests steht aus, da dafür noch keine separate Build-/Testfreigabe erteilt wurde.

**2026-07-12T15:32:31Z**

Laufzeitverifikation erfolgreich: RecommendationServiceTests gezielt auf iPhone 17e mit iOS 26.5 ausgeführt. 14/14 Tests in 1 Suite bestanden, Swift-Testing-Laufzeit 0,065 s; xcodebuild meldet TEST SUCCEEDED. Normale lokale Simulator-Signierung mit CloudKit-Entitlements verwendet.
