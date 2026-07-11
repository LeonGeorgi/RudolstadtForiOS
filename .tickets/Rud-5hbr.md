---
id: Rud-5hbr
status: open
deps: []
links: []
created: 2026-07-11T07:04:51Z
type: epic
priority: 1
assignee: Leon Georgi
tags: [needs-approval, tests, architecture, testability]
---
# Testfundament und Testbarkeit modernisieren

Die bestehende Test Suite strukturell modernisieren und die produktive Architektur dort gezielt testbar machen, wo globale Abhängigkeiten, Initializer-Nebenwirkungen oder Systemframeworks heute deterministische Tests verhindern.

## Design

Inkrementell im bestehenden App-Target vorgehen. Swift Testing für Unit- und Service-Tests einführen, XCTest für UI- und Performance-Tests behalten. Kein eigenes Core-Modul erzwingen; eine spätere Extraktion nur bei nachgewiesenem Nutzen.

## Acceptance Criteria

Die bestehenden Testfälle sind geordnet und erhalten; relevante Abhängigkeiten lassen sich ohne globale Prozesszustände injizieren; Tests können isoliert und parallel ausgeführt werden; die Child-Tickets dieses Epics sind abgeschlossen.
