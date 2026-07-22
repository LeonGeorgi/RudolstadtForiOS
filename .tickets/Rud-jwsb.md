---
id: Rud-jwsb
status: in_progress
deps: []
links: []
created: 2026-07-22T00:19:13Z
type: feature
priority: 2
assignee: Leon Georgi
tags: [approved, schedule, interaction]
---
# Schedule-Timeline: Horizontalen und vertikalen Pinch-Zoom unabhängig skalieren

Die Zwei-Finger-Geste soll Bühnenbreite und Zeithöhe unabhängig voneinander skalieren. Bewegung des Finger-Mittelpunkts scrollt weiterhin beide Achsen.

## Design

Aus der Änderung der horizontalen und vertikalen Fingerabstände getrennte Skalierungsfaktoren ableiten, gegen instabile nahezu null große Ausgangskomponenten absichern und beide Content-Anker in einem Frame-Update stabil halten.

## Acceptance Criteria

Horizontale Finger-Spreizung verändert nur die Bühnenbreite; vertikale Spreizung nur die Zeithöhe. Kombinierte Bewegung skaliert und scrollt beide Achsen gleichzeitig. Bühne unter dem horizontalen und Zeitpunkt unter dem vertikalen Fingerzentrum bleiben außer an Scrollgrenzen stabil. Ein-Finger-Scrollen, Navigation, Kontextmenüs und Tap-Unterdrückung bleiben erhalten.

## Notes

**2026-07-22T00:26:13Z**

Implementiert: Die Zwei-Finger-Geometrie liefert getrennte horizontale und vertikale Vergrößerung aus den Änderungen der jeweiligen Fingerabstände relativ zum stabilisierten gesamten Startabstand. Bühnenbreite skaliert von 48 bis 140 pt, Zeithöhe weiterhin von 42 bis 120 pt/Stunde. Bewegungen des Mittelpunkts scrollen beide Achsen; der Bühnenpunkt und Zeitpunkt unter dem Mittelpunkt werden über eine spalten- und abstandsbewusste Ankerabbildung stabil gehalten. Frame-Bündelung und Tap-Sperre bleiben erhalten. Tests ergänzt für unabhängige Achsen, reine Pan-Bewegung, horizontale/vertikale Grenzen, stabilen horizontalen Anker und Scrollkanten. Geprüft: isolierter iOS-18-SwiftUI-Typecheck, iOS-/macOS-Zoom-Typecheck und Parse, ausgeführte Logik-Assertions, Swift-Testing-Quellcode-Typecheck, PBX-Lint und diff-check. Ausstehend: Touch-/Darstellungsprüfung in App oder Simulator.

**2026-07-22T00:35:49Z**

Vereinfachung nach Implementierung: Die spalten- und abstandsbewusste horizontale Ankerabbildung verwendet nun eine kompakte Deltaformel aus vollständig durchlaufenen Spalten und dem Fortschritt innerhalb der aktuellen Spalte. Die neue Formel wurde für 0 bis 16 Bühnen, den vollständigen Breitenbereich und tausende Ankerpositionen exakt gegen die vorherige Implementierung geprüft. ScheduleTimelineZoomMagnification besitzt Standardwerte von 1; Tests verwenden den gemeinsamen Session-Helper und kürzere achsenspezifische Konstruktionen. Verhalten und Grenzwerte unverändert. iOS-/macOS-Typecheck und Parse, Swift-Testing-Quellcode-Typecheck sowie diff-check erfolgreich.
