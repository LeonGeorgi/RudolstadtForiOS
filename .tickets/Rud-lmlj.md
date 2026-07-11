---
id: Rud-lmlj
status: open
deps: [Rud-3kry, Rud-7cn0]
links: []
created: 2026-07-11T07:04:53Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-gqey
tags: [needs-approval, tests, ui-tests, fixtures, testability, effort-medium, confidence-high]
---
# Deterministischen UI-Testmodus mit lokalen Fixtures einführen

Einen expliziten UI-Testmodus bereitstellen, der App-Zustand und Daten reproduzierbar initialisiert und externe Dialoge sowie Dienste aus der normalen UI-Testausführung fernhält.

## Design

An den vorhandenen ScreenshotRuntime-Ansätzen ausrichten, aber UI-Testzustand semantisch getrennt konfigurieren. Bundle-Fixtures, isolierte UserDefaults, feste Festivalzeit, deaktiviertes CloudKit, deaktivierte Notifications und kein Netzwerk verwenden.

## Acceptance Criteria

Jeder UI-Test startet unabhängig mit demselben bekannten Zustand; kein Test benötigt Netzwerk, iCloud oder Berechtigungsdialoge; Startdaten und feste Zeit sind explizit steuerbar; die Produktion startet weiterhin mit den echten Adaptern.
