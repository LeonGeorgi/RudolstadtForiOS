---
id: Rud-4lwc
status: closed
deps: []
links: [Rud-fww4, Rud-tuxh, Rud-ure7]
created: 2026-07-11T03:11:28Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-sw5e
tags: [approved, design-audit, ios26, artists, map, voiceover, effort-medium, confidence-high]
---
# Künstler-Weltkarte zugänglich ergänzen

Länder werden als MapPolygons über SpatialTapGesture gewählt und bilden keine verlässlichen VoiceOver- oder Voice-Control-Ziele.

## Design

Die immersive Karte behalten und um eine gleichwertige sortierte Länderliste oder Accessibility-Repräsentation mit Land, Künstlerzahl und Auswahlzustand ergänzen.

## Acceptance Criteria

Alle Länder mit Künstlern sind ohne direkte Kartenberührung erreichbar; VoiceOver nennt Land und Künstlerzahl; Navigation zum Länder-Screen funktioniert; Karte, Kamera und visuelle Choroplethen-Darstellung bleiben erhalten.

## Notes

**2026-07-11T06:26:55Z**

Vom Nutzer am 2026-07-11 ausdrücklich genehmigt; Umsetzung begonnen.

**2026-07-11T06:27:48Z**

Accessibility-Repräsentation der Weltkarte implementiert: alphabetisch sortierte Länder-Buttons mit lokalisierter Künstlerzahl, Auswahlstatus und Navigation zum Länder-Screen. Sichtbare MapKit-Karte und SpatialTapGesture bleiben unverändert. Diff-Prüfung erfolgreich; Build/Simulatorprüfung gemäß Projektvorgabe nicht ohne ausdrücklichen Auftrag ausgeführt.

**2026-07-11T06:33:53Z**

Automatisierte Absicherung als Folgeticket Rud-ure7 erfasst.
