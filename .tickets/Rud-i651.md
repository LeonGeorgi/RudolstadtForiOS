---
id: Rud-i651
status: closed
deps: []
links: []
created: 2026-07-20T10:47:44Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved, ios26, artist-detail, design, accessibility]
---
# Künstlerdetail: metrischen Feinschliff angleichen

Feinabstimmung des bestehenden Künstlerdetail-Layouts ohne Änderung des 40-pt-Gesamtrands am Hero-Bild und ohne Änderung von .title.bold().

## Design

Metadaten verdichten, vertikalen Rhythmus vereinheitlichen, Rating- und Freundesindikatoren optisch normalisieren, Inhaltskarten und Event-Time-Badge beruhigen, Social-Icons optisch ausgleichen und den doppelten Abstand vor der KI-Zusammenfassung entfernen.

## Acceptance Criteria

Hero-Bild behält 40 pt Gesamtrand und 8:7; Künstlername bleibt .title.bold(); direkte Bewertung und Links bleiben direkt erreichbar; Abstände, Radien, Schatten und Icongewichte wirken konsistent; Dynamic Type bleibt adaptiv; relevante Dateien parsen und git diff --check ist sauber.

## Notes

**2026-07-20T10:54:37Z**

Metrischen Feinschliff umgesetzt: Bild-Gesamtrand (40 pt im Standardlayout), Seitenverhältnis und .title.bold() unverändert gelassen; Metadatenrhythmus, Abstände, kompakte Bewertung/Freundesindikator, Social-Icon-Skalierung, Kartenradien, Event-Badge und Chevron-Kontrast harmonisiert. Verifiziert mit swiftc -parse der betroffenen Swift-Dateien, plutil -lint für DE/EN und git diff --check. Kein Build oder Simulatorlauf in diesem Turn, da nicht erneut autorisiert.
