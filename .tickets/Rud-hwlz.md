---
id: Rud-hwlz
status: closed
deps: []
links: [Rud-tuxh]
created: 2026-07-11T04:21:04Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, artist-detail, visual-design, navigation-title, effort-small, confidence-high]
---
# Künstlerdetail: Seitentitel und Navigationstitel über den Scrollzustand zusammenführen

Der Künstlername erscheint am Anfang der Seite groß im Inhalt und gleichzeitig als kompakter Navigationstitel. In der gerenderten Ansicht konkurrieren beide Instanzen unmittelbar miteinander und schwächen die Blickführung, obwohl beide funktional korrekt sind.

Betroffene Stellen:
- Shared/Screens/Artist/Detail/ArtistDetailView.swift, insbesondere navigationTitle und Toolbar
- Shared/Screens/Artist/Detail/ArtistDetailHeaderView.swift, insbesondere der Titel im Header

Priorität: mittel
Aufwand: klein
Sicherheit: hoch

## Design

Am oberen Scrollanfang bleibt ausschließlich der große Künstlername im Inhalt der visuelle Seitentitel. Der kompakte Navigationstitel wird erst eingeblendet, wenn der große Titel vollständig oder weitgehend unter die Navigationsleiste gescrollt ist. Dafür eine robuste SwiftUI-Lösung mit Scrollgeometrie beziehungsweise Sichtbarkeitszustand verwenden, passend zur bestehenden Mindestplattform.

Zurück-Navigation und vorhandene Toolbar-Aktionen bleiben an ihrem erwartbaren Systemplatz. Der Übergang soll ruhig und systemnah sein, ohne eigenes Morphing, Glas-Overlay oder auffällige Animation.

Nicht-Ziele:
- keine Änderung der Titeltypografie im Header über das für den Übergang Nötige hinaus
- keine neue eigene Navigationsleiste
- keine Änderung der Toolbar-Aktionen

## Acceptance Criteria

- Am oberen Rand ist der Künstlername nicht doppelt sichtbar.
- Beim Scrollen erscheint der Navigationstitel erst, nachdem der große Inhaltstitel seine Funktion nicht mehr erfüllt.
- Beim Zurückscrollen verschwindet der kompakte Titel wieder ohne Flackern oder Layoutsprung.
- Der Übergang funktioniert mit ein- und mehrzeiligen Künstlernamen sowie bei größeren Dynamic-Type-Stufen.
- Back-Button und Toolbar-Aktionen bleiben stabil positioniert.
- Das Verhalten wurde in Light und Dark Mode sowie mindestens auf einem kleinen und einem großen iPhone geprüft.

## Notes

**2026-07-12T16:27:27Z**

Scrollabhängige Titelübergabe mit onScrollVisibilityChange am Inhaltstitel umgesetzt. Simulator-Build erfolgreich. Auf iPhone 17 / iOS 26.4 mit 5/8erl und A Schwoazzes Gebiss geprüft: oberer, gescrollter und zurückgescrollter Zustand sowie Light/Dark Mode; kein doppelter Titel oder Layoutsprung beobachtet. Nutzer hat auf weitere visuelle Prüfung auf kleinem/großem Gerät und Dynamic Type verzichtet. Keine Tests ausgeführt.
