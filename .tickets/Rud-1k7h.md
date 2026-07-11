---
id: Rud-1k7h
status: open
deps: [Rud-e1lc]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 0
assignee: Leon Georgi
parent: Rud-sa0w
tags: [needs-approval, tests, schedule, recommendations, date-time, regression, effort-large, confidence-high]
---
# Programm-, Zeitkonflikt- und Empfehlungslogik umfassend absichern

Die zentrale Programm- und Empfehlungslogik mit Beispieltests, parametrisierten Grenzfällen und deterministisch erzeugten Invarianten absichern.

## Design

Event-Tageswechsel, Laufwege, Ankunftspuffer, Dauerabschätzung, Filter und RecommendationService gemeinsam betrachten. Für größere generierte Spielpläne feste Seeds verwenden und fachliche Invarianten statt konkreter Implementierungsdetails prüfen.

## Acceptance Criteria

Tests belegen: gespeicherte Events bleiben erhalten; Empfehlungen überschneiden sich nicht; pro Artist wird höchstens ein Event empfohlen; vergangene Events werden ausgeschlossen; Rating-Prioritäten und stabile Reihenfolge gelten; Mitternacht, Laufwege, Puffer und Dauergrenzen sind abgedeckt.
