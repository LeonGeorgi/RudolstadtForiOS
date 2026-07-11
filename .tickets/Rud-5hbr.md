---
id: Rud-5hbr
status: closed
deps: []
links: []
created: 2026-07-11T07:04:51Z
type: epic
priority: 1
assignee: Leon Georgi
tags: [approved, tests, architecture, testability]
---
# Testfundament und Testbarkeit modernisieren

Die bestehende Test Suite strukturell modernisieren und die produktive Architektur dort gezielt testbar machen, wo globale Abhängigkeiten, Initializer-Nebenwirkungen oder Systemframeworks heute deterministische Tests verhindern.

## Design

Inkrementell im bestehenden App-Target vorgehen. Swift Testing für Unit- und Service-Tests einführen, XCTest für UI- und Performance-Tests behalten. Kein eigenes Core-Modul erzwingen; eine spätere Extraktion nur bei nachgewiesenem Nutzen.

## Acceptance Criteria

Die bestehenden Testfälle sind geordnet und erhalten; relevante Abhängigkeiten lassen sich ohne globale Prozesszustände injizieren; Tests können isoliert und parallel ausgeführt werden; die Child-Tickets dieses Epics sind abgeschlossen.

## Notes

**2026-07-11T08:33:02Z**

Epic abgeschlossen: Alle vier Child-Tickets (Rud-8z2c, Rud-e1lc, Rud-3kry und Rud-7cn0) sind geschlossen. Die Unit-Tests sind nach Verantwortungen strukturiert und auf Swift Testing migriert; UserDefaults, Zeit/Locale, API/Cache/Festivaldaten sowie Festivalprofil-Persistenz und Sync-Regeln besitzen fokussierte Test-Seams. Verifikation über die Child-Tickets: vollständige Suite mit 56/56 Tests zweimal erfolgreich und parallel reproduzierbar; anschließend 5/5 gezielte API-/Festivaldaten-Tests sowie 9/9 FestivalProfileStore-Tests erfolgreich. Ein erneuter integrierter Lauf im aktuellen Arbeitsbaum bleibt wegen einer unabhängigen unvollständigen FriendsView-Änderung blockiert; die finalen Profiländerungen wurden deshalb erfolgreich in einer sauberen HEAD-Kopie geprüft.
