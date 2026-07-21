---
id: Rud-22vf
status: in_progress
deps: []
links: []
created: 2026-07-21T14:11:15Z
type: feature
priority: 2
assignee: Leon Georgi
tags: [approved, schedule, interaction]
---
# Schedule-Timeline: Vertikalen Pinch-Zoom mit stabilem Zeitanker ergänzen

Die vertikale Zeitskala der Schedule-Timeline soll per Pinch-Geste vergrößert und verkleinert werden. Der Zeitpunkt unter dem Gestenmittelpunkt bleibt während des Zoomens möglichst an derselben Bildschirmposition; der horizontale Offset bleibt unverändert.

## Design

heightPerHour innerhalb sinnvoller Grenzen skalieren. Beim Gestenbeginn aus Scroll-Offset, Fingerposition und Timeline-Ursprung einen Zeitanker berechnen. Während der Geste den neuen vertikalen Offset über ScrollPosition ohne Animation nachführen und an den erlaubten Scrollbereich begrenzen. macOS-12-Kompatibilität der gemeinsamen Datei erhalten.

## Acceptance Criteria

Pinch verändert nur die vertikale Dichte. Der verankerte Zeitpunkt bleibt außer an Scrollgrenzen stabil. Bühnenbreiten, horizontale Position, Eventdauer, Zeitraster und Jetzt-Linie bleiben synchron. Normales zweiachsiges Scrollen, Navigation, Kontextmenüs und Speichern funktionieren weiterhin.

## Notes

**2026-07-21T14:21:41Z**

Implementiert: vertikaler Pinch-Zoom von 42 bis 120 pt/Stunde mit MagnifyGesture, stabiler Zeitanker-Berechnung, Erhalt des horizontalen Offsets und programmatischer ScrollPosition ohne Animation. Zoom-Mathematik in ScheduleTimelineZoom.swift extrahiert und mit vier Swift-Testing-Fällen für Anker, Grenzen und Skalenlimits abgedeckt. Geprüft: isolierter iOS-18-Zoom-API-Typecheck, macOS-12.2-Fallback-Typecheck, fokussierter Logik-Compile mit ausgeführten Assertions, Testquellcode-Typecheck, iOS-/macOS-Parse, PBX-Lint und diff-check. Ausstehend: App-/Simulatorprüfung von Pinch, Scrollkonflikten und visueller Synchronität (kein Build oder App-Start autorisiert).

**2026-07-21T14:40:34Z**

2026-07-21: Zoom-Gestenwerte werden jetzt über CADisplayLink auf höchstens den jeweils neuesten Wert pro Display-Frame zusammengefasst. Exakt identische Updates sowie Änderungen unter 0,25 pt/Stunde und 0,5 pt Content-Offset werden übersprungen; die letzte Geste wird weiterhin exakt angewendet. Geprüft: isolierter SwiftUI-/iOS-Typecheck, Swift-Testing-Quellcode-Typecheck, ausgeführte Schwellwert-Assertions, iOS-/macOS-Parse, PBX-Lint und diff-check. Ausstehend: subjektive Laufzeitprüfung des Zoom-Ruckelns auf Gerät/Simulator.

**2026-07-21T14:43:30Z**

2026-07-21: Nach Nutzerfeedback zu seltenen starken Offset-Ausschlägen die konkurrierende native Scroll-Geste während einer aktiven MagnifyGesture deaktiviert. Der ScrollView bleibt vor und nach dem Pinch normal scrollbar; während des Pinchs setzt ausschließlich die ankerstabile Zoom-Logik den Offset. Isolierter SwiftUI-Typecheck, iOS-/macOS-Parse und diff-check erfolgreich; Laufzeitprüfung durch den Nutzer ausstehend.

**2026-07-21T14:51:52Z**

2026-07-21: Pinch-Interaktion auf SpatialEventGesture umgestellt. Während zwei Finger aktiv sind, werden deren Abstand (vertikale Skalierung) und gemeinsamer Mittelpunkt (horizontales/vertikales Scrollen) zu genau einem ankerstabilen Ziel pro Display-Frame kombiniert; der native ScrollView bleibt nur für diese Zwei-Finger-Sequenz gesperrt. Ein-Finger-Scrollen bleibt nativ. Zoom-/Pan-Mathematik um beweglichen Viewport-Anker und horizontale Begrenzung erweitert; Tests für kombinierten Zoom+Pan und horizontale Kante ergänzt. Geprüft: isolierter iOS-18-SpatialEventGesture-Typecheck, iOS-/macOS-Zoom-Typecheck und Parse, ausgeführte Logik-Assertions, Swift-Testing-Quellcode-Typecheck, PBX-Lint und diff-check. Laufzeit-/Touchprüfung ausstehend.

**2026-07-21T14:53:18Z**

2026-07-21: Versehentliche Navigation nach dem Pinch verhindert. Der interaktive Timeline-Inhalt ist während der Zwei-Finger-Zoom-Session bis einschließlich des abschließenden Display-Frames deaktiviert, sodass NavigationLinks und Kontextmenüs die ursprünglichen Fingerkontakte nicht nachträglich als Tap abschließen können. SpatialEventGesture am umgebenden ScrollView und normales Ein-Finger-Verhalten außerhalb der Session bleiben unverändert. Isolierter SwiftUI-Typecheck, iOS-/macOS-Parse und diff-check erfolgreich; Laufzeitprüfung ausstehend.

**2026-07-21T14:56:48Z**

2026-07-21: Die Tap-Unterdrückung verwendet nun allowsHitTesting statt disabled. Dadurch bleiben Event-Zellen während des Pinchs visuell unverändert, während ihre NavigationLinks und Kontextmenüs weiterhin keine Berührungen abschließen können; die SpatialEventGesture bleibt am ScrollView aktiv. Isolierter SwiftUI-Typecheck, iOS-/macOS-Parse und diff-check erfolgreich; Laufzeitprüfung ausstehend.

**2026-07-21T14:59:59Z**

2026-07-21: Tap-Unterdrückung wieder robust über disabled umgesetzt, aber die Event-NavigationLinks verwenden nun einen eigenen ButtonStyle, der den deaktivierten Zustand nicht visuell darstellt. Normale Taps behalten ein dezentes Press-Feedback; während des Zooms bleiben die Zellen vollständig unverändert und Navigation wird trotzdem blockiert. Isolierter ButtonStyle-Typecheck, iOS-/macOS-Parse und diff-check erfolgreich; Laufzeitprüfung ausstehend.

**2026-07-21T15:02:04Z**

2026-07-22: Auf Nutzerwunsch den eigenen undimmed Timeline-ButtonStyle vollständig entfernt. Event-Zellen verwenden wieder .buttonStyle(.plain); die zuverlässige disabled-Sperre während des Zwei-Finger-Zooms bleibt bestehen, einschließlich ihrer normalen SwiftUI-Darstellung. iOS-/macOS-Parse und diff-check erfolgreich.

**2026-07-21T15:06:50Z**

2026-07-22: Zoom-Code vereinfacht. Die redundante erneute Finalwert-Anwendung samt latestSample-/force-Pfad wurde entfernt; beim Gestenende verarbeitet der Frame-Scheduler nur noch sein bereits vorgemerktes neuestes Update und hält anschließend die Tap-Sperre bis zum Abschluss-Frame. horizontalOffset und verticalOffset werden nun aus dem einzigen gespeicherten contentOffset abgeleitet statt separat synchronisiert. Geprüft: isolierter Observation-Laufzeittest für berechnete Offsets, iOS-/macOS-Typecheck und Parse, ausgeführte Zoom-Assertions, Swift-Testing-Quellcode-Typecheck, PBX-Lint und diff-check. Laufzeit-/Touchprüfung ausstehend.
