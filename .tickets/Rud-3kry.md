---
id: Rud-3kry
status: closed
deps: [Rud-e1lc]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-5hbr
tags: [approved, tests, testability, api, cache, data-store, effort-large, confidence-high]
---
# API-, Cache- und Festivaldaten-Orchestrierung injizierbar machen

APIClient, DataLoader und DataStore so entkoppeln, dass Download-, Cache-, Fallback- und Nebenläufigkeitsabläufe ohne echtes Netzwerk oder den globalen Cache getestet werden können.

## Design

URLSession beziehungsweise einen schmalen HTTP-Client und Base-URL injizieren; FestivalDataFetching und FestivalDataCaching als fokussierte Grenzen verwenden; Initializer-I/O im DataStore vermeiden oder explizit steuerbar machen. Produktionsadapter bleiben die Defaults.

## Acceptance Criteria

API-Antworten und Fehler sind mit kontrollierten Stubs simulierbar; DataStore-Tests können einen temporären oder in-memory Cache verwenden; die Initialisierung löst in Tests keine unerwarteten externen Zugriffe aus; Produktionsaufrufe benötigen keine zusätzliche Konfiguration.

## Notes

**2026-07-11T08:10:02Z**

Implementiert: APIClient akzeptiert einen schmalen HTTPClient und eine Base-URL; URLSessionHTTPClient bleibt Produktionsdefault. FestivalDataFetching, FestivalDataCaching und BundledNewsLoading entkoppeln DataStore von APIClient/DataLoader. loadInitialData=false verhindert Initializer-I/O in Tests; Produktionsaufrufe behalten automatische Defaults. In-Memory-Stubs und 5 Tests decken Base-URL, HTTP-Fehler, passive Initialisierung, Fresh-Cache und Fetch+Store ab. Gezielte Verifikation auf iPhone 17e/iOS 26.5: APIClientTests und FestivalDataStoreTests, 5/5 bestanden; Produktionsaufrufer kompiliert. plutil und git diff --check erfolgreich. Keine vollständige Testsuite ausgeführt; die umfassende Fallback-/Concurrency-Matrix bleibt Rud-tlev.
