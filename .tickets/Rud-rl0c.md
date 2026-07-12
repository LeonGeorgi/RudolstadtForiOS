---
id: Rud-rl0c
status: open
deps: []
links: [Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, map, visual-design, markers, legend, liquid-glass, effort-medium, confidence-high]
---
# Festival-Lageplan: Marker und Filterlegende visuell vereinfachen

Der vollflächige Lageplan harmoniert grundsätzlich sehr gut mit der schwebenden iOS-26-Systemoberfläche; insbesondere der runde Recenter-Button ist eine passende Verwendung von Liquid Glass. Die Bühnenmarker verwenden dagegen mehrere Glanzlichter, Innenkonturen, Außenkonturen und Schatten und wirken dadurch wie ältere glossy Pins. Oberhalb der Karte konkurrieren bis zu drei einzelne Filter-Chips plus Discoverability-Tipp um Aufmerksamkeit und verdecken einen relativ großen Kartenbereich.

Betroffene Stellen:
- Shared/Screens/Map/MapView.swift, insbesondere renderCircle, legendToggleChip und die oberen Overlays
- Shared/Screens/Map/MapOverview.swift
- Shared/Screens/Location/StageNumber.swift für die bestehende semantische Farblogik

Priorität: mittel
Aufwand: mittel
Sicherheit: hoch

## Design

Die Karte als Content-Fläche und die Controls als funktionale iOS-26-Schicht klar trennen:
- Marker auf eine flache, kontrastreiche Grundform mit höchstens einer notwendigen Kontur reduzieren
- Typ-/Statusfarbe beibehalten, aber dekorative Glanzpunkte, doppelte Innenringe und schweren Schatten entfernen
- Markergröße und Kontur anhand heller, dunkler und detailreicher Kartenregionen testen
- die drei Filter als eine zusammengehörige kompakte Kontrollgruppe gestalten statt als drei konkurrierende Einzelpillen
- aktiven und inaktiven Zustand nicht nur über Sättigung und Opazität, sondern über ruhige systemnahe Auswahlbehandlung unterscheiden
- Discoverability-Tipp temporär halten und danach keinen leeren oder zusätzlichen Materiallayer zurücklassen
- den bestehenden Recenter-Button als visuelle Referenz erhalten

Nicht-Ziele:
- keine Änderung der MapKit-Kamera oder Standortlogik
- keine vollständige Glasfläche über der Kartenbreite
- keine dekorativen 3D-Pins
- keine Entfernung der Filter

## Acceptance Criteria

- Marker bleiben auf hellen, dunklen und textreichen Kartenausschnitten sofort erkennbar, wirken aber nicht glossy.
- Die Legende wird als eine funktionale Gruppe gelesen und verdeckt weniger Karteninhalt.
- Alle drei Filterzustände sind eindeutig, auch wenn einzelne Kategorien deaktiviert sind.
- Der Recenter-Button behält seine native iOS-26-Glass-Darstellung.
- Nach Ausblenden des Tipps bleibt die obere Komposition ausgewogen.
- Prüfung umfasst Light und Dark Mode, verschiedene Zoomstufen, Markercluster sowie kleine und große iPhones.

