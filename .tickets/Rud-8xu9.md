---
id: Rud-8xu9
status: open
deps: [Rud-vb4t]
links: [Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 3
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, more, visual-design, icons, tint, effort-small, confidence-high]
---
# Mehr-Screen: Icon-, Tint- und Zeilenausrichtung nach der Neugliederung verfeinern

Rud-vb4t erfasst bereits die notwendige native Gliederung und Systemtypografie des Mehr-Screens. Zusätzlich wirken die aktuell gemischten SF-Symbole info, car, bus, heart, gearshape und icloud optisch unterschiedlich schwer und breit. Durch die überall gleiche Akzentfärbung beziehungsweise gleichartige Zeilenbehandlung besitzen About, Mobilität, Spende, Einstellungen und Sync nahezu dasselbe visuelle Gewicht. Der Icon-/Text-Gutter wirkt dadurch weniger präzise als bei einer aktuellen nativen Settings-Oberfläche.

Betroffene Stelle:
- Shared/Screens/More/MoreView.swift

Priorität: niedrig
Aufwand: klein
Sicherheit: hoch

## Design

Nach der in Rud-vb4t definierten Section-Gliederung die Zeilen visuell kalibrieren:
- SF-Symbole nach semantisch passenden Varianten und ähnlicher optischer Strichstärke auswählen
- feste Symbolspalte beziehungsweise systemeigenes Label-Alignment nutzen, damit Textanfänge exakt fluchten
- Accent Color für echte Aktion, Status oder ausgewählte Bedeutung reservieren; normale Navigationssymbole dürfen primary beziehungsweise secondary verwenden
- Spende darf gezielt wärmer oder akzentuiert sein, sofern sie nicht stärker als wichtige Einstellungen oder Sync-Fehler wirkt
- Sync-Status visuell nur dann hervorheben, wenn ein tatsächlicher Status dies rechtfertigt
- native List- und Section-Darstellung von iOS 26 arbeiten lassen, ohne eigene Zeilen-Cards oder zusätzliche Materialien

Nicht-Ziele:
- keine eigene Icon-Assetfamilie
- keine Kachelübersicht
- keine Änderung der Navigation oder Zielreihenfolge außerhalb von Rud-vb4t
- keine feste Punktgröße

## Acceptance Criteria

- Alle Textlabels beginnen auf einer konsistenten vertikalen Achse.
- Symbole wirken trotz unterschiedlicher Formen optisch ähnlich schwer und eindeutig semantisch.
- Akzentfarbe markiert Bedeutung und wird nicht dekorativ auf jede Zeile angewandt.
- Normaler und problematischer Sync-Zustand besitzen eine nachvollziehbare Hierarchie.
- Ergebnis entspricht der nativen iOS-26-Listendarstellung ohne zusätzliche Cards.
- Light und Dark Mode sowie deutsche und englische Beschriftungen wurden geprüft.

