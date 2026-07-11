---
id: Rud-m87x
status: open
deps: [Rud-e1lc]
links: [Rud-ure7]
created: 2026-07-11T07:04:53Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-sa0w
tags: [needs-approval, tests, preferences, search, filters, app-state, localization, effort-medium, confidence-high]
---
# Preferences, Suche, Filter und Präsentationszustände absichern

Die kleineren, aber breit genutzten Zustands- und Präsentationsregeln für Einstellungen, Suche, Artist-Übersicht, Länder und Datumsanzeige mit fokussierten Unit-Tests absichern.

## Design

Parametrisierte Tabellen für Settings-Mappings, normalisierte Suche, Filter-Synchronisierung, Locale-Ausgaben und ungültige gespeicherte Werte verwenden. Die separat bestehende Weltkarten-Accessibility-Aufgabe Rud-ure7 nicht duplizieren.

## Acceptance Criteria

Schedule-, Artist- und Map-Einstellungen roundtrippen korrekt; ungültige Werte fallen definiert zurück; Suche behandelt Leerraum, Großschreibung und Diakritika; Artist-Filter werden korrekt synchronisiert; relevante Locale- und Festivaltagesfälle sind deterministisch getestet.
