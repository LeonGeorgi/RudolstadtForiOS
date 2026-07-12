---
id: Rud-t6ld
status: open
deps: [Rud-r2ax]
links: [Rud-tuxh]
created: 2026-07-11T04:21:05Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artist-detail, visual-design, events, effort-medium, confidence-high]
---
# Künstlerdetail: Auftrittsblock flacher und farblich in die Künstlerseite integrieren

Der Auftrittsblock ist informativ und die Zeit-Badges funktionieren als gute Anker. Die relativ starke eigenständige Hintergrundfläche mit Radius 24 wirkt jedoch wie eine große generische Card innerhalb der individuellen Künstlerseite. In hellen Paletten kann sie sich zu stark absetzen; in der Zeile konkurrieren gespeicherter Status und Chevron teilweise als gleichwertige Ziele.

Betroffene Stellen:
- Shared/Screens/Artist/Detail/ArtistEventsBlock.swift
- Shared/Screens/Artist/Detail/ArtistEventCell.swift

Priorität: mittel
Aufwand: mittel
Sicherheit: hoch

## Design

Den Block als ruhige Inhaltssektion statt als aufgesetzte Card gestalten:
- Eventfläche aus dem zentralen fotoabgeleiteten Theme beziehen
- Flächenkontrast im Light Mode reduzieren, im Dark Mode dennoch eine klare Gruppierung bewahren
- Radius zunächst im Bereich 18 bis 20 statt 24 Punkte prüfen
- Zeit-Badges als primären visuellen Anker erhalten
- gespeicherten Status als relevante Aktion erkennbar lassen
- Chevron eindeutig tertiär behandeln, beispielsweise kleiner oder kontrastärmer, ohne Navigationsaffordanz zu verlieren
- Divider und Innenabstände auf einen konsistenten vertikalen Rhythmus abstimmen

Nicht-Ziele:
- keine Änderung an Eventdaten, Navigation oder Save-Logik
- keine zusätzliche Card pro Event
- keine Glasfläche hinter dem gesamten Block
- keine Entfernung der bewährten Zeit-Badges

## Acceptance Criteria

- Der Eventblock ist klar gruppiert, wirkt aber als Teil der jeweiligen Künstlerfarbwelt und nicht wie eine fremde Standard-Card.
- Ein, zwei und mindestens vier Auftritte funktionieren ohne übermäßige Leere oder visuelle Enge.
- Zeit, Bühne, Freundestatus, Save-Status und Navigation besitzen eine eindeutige visuelle Rangfolge.
- Divider und Zeilenabstände sind in allen Zeilen konsistent.
- Sehr helle und sehr dunkle Künstlerpaletten wurden in Light und Dark Mode geprüft.
- Das Layout bleibt bei langen Bühnennamen und größeren Textgrößen stabil.

