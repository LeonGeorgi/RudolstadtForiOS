---
id: Rud-ckpo
status: in_progress
deps: []
links: [Rud-nyap]
created: 2026-07-20T16:33:33Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved, performance, schedule]
---
# Schedule-Timeline: Scroll-State vom Konzertbaum isolieren

Die Timeline schreibt den Scroll-Offset derzeit bei jeder horizontalen oder vertikalen Bewegung in State von ScheduleTimelineContentView. Dadurch wird der große Konzertbaum zusammen mit den kleinen angehefteten UI-Elementen invalidiert. Das Scroll-Tracking soll so gekapselt werden, dass nur Uhrzeitenskala, Bühnenköpfe und aktuelle-Zeit-Linie den Offset beobachten.

## Design

Den statischen Konzertbereich in eine eigene View extrahieren. Den Offset über die für das Deployment Target geeignete Scroll-Geometrie-API in einem kleinen Observation-State halten, dessen Werte ausschließlich die Timeline-Chrome-Overlays lesen. Navigation, Kontextmenüs, Speichern und die zweiachsige Scrollbarkeit bleiben unverändert.

## Acceptance Criteria

Horizontales und vertikales Scrollen hält Uhrzeitenskala, Bühnenköpfe und aktuelle-Zeit-Linie weiterhin korrekt ausgerichtet. Reine Offset-Änderungen führen nicht mehr zur fortlaufenden Neuauswertung der Konzertkarten; dies wird mit gezielter Debug-Instrumentierung oder Instruments geprüft. Tageswechsel, Profiländerungen, Navigation, Kontextmenüs und Speichern funktionieren weiterhin. Keine visuelle Neugestaltung der Timeline.

## Notes

**2026-07-21T13:52:41Z**

Implementiert: Konzert-Canvas vom Scroll-State getrennt; iOS 18 nutzt onScrollGeometryChange mit granularer Observation, macOS 12.2 behält einen gekapselten PreferenceKey-Fallback. Geprüft: iOS-/macOS-Syntax, isolierter API-Typecheck für iOS 18 und macOS 12.2, git diff --check. Ausstehend: App-/Simulatorprüfung der Ausrichtung und Instruments- bzw. Debug-Instrumentierung der Body-Neuauswertungen (kein Build oder App-Start autorisiert).
