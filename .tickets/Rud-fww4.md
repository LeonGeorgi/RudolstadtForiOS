---
id: Rud-fww4
status: open
deps: []
links: [Rud-4lwc, Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artists, world-map, visual-design, color, effort-medium, confidence-medium]
---
# Künstler-Weltkarte: Choroplethen-Farben und Kartenbasis besser ausbalancieren

Die immersive Weltkarte ist ein eigenständiges, starkes Discovery-Element. In der gerenderten Ansicht konkurrieren jedoch die detaillierte MapKit-Basiskarte und die eingefärbten Länderpolygone miteinander. Mittlere Violetttöne wirken auf einzelnen Kartenfarben etwas grau oder schmutzig, und ohne eine knappe visuelle Erklärung bleibt unklar, ob stärkere Farbe für Auswahl, Künstlerzahl oder bloße Verfügbarkeit steht.

Betroffene Stellen:
- Shared/Screens/Artist/Overview/ArtistWorldMapView.swift
- Shared/Screens/Artist/Overview/ArtistMapOverviewView.swift
- Shared/Screens/Artist/Overview/ArtistWorldMapCalloutCard.swift

Das alternative zugängliche Länderangebot ist bereits in Rud-4lwc erfasst.

Priorität: mittel
Aufwand: mittel
Sicherheit: mittel, weil die endgültige Palette auf realen Kartenzuständen geprüft werden muss

## Design

Die Choroplethenebene als klare Informationsschicht vor einer ruhigeren Kartenbasis gestalten:
- eine kleine semantische Farbskala für ohne Künstler, mit Künstlern und ausgewählt definieren; Künstlerzahl nur dann zusätzlich abstufen, wenn diese Bedeutung sichtbar erklärt wird
- Violetttöne so anpassen, dass sie auf Land, Wasser und im Dark Mode sauber und markentypisch statt grau wirken
- Basiskartenkontrast beziehungsweise Map-Style soweit systemseitig möglich zurücknehmen, ohne Orientierungspunkte vollständig zu verlieren
- Ländergrenzen und Auswahlkontur auf eine eindeutige Rolle reduzieren
- eine sehr kompakte Erklärung oder Legende nur ergänzen, wenn die Farbstärke tatsächlich Daten codiert
- schwebende Systemcontrols in iOS 26 systemnah lassen; keine Glasflächen direkt auf die Länderpolygone legen

Nicht-Ziele:
- keine Entfernung der interaktiven Weltkarte
- keine reine Listenansicht als visueller Ersatz
- keine Regenbogen-Farbskala
- keine Änderung der Country-Navigation oder Datenaggregation

## Acceptance Criteria

- Länder mit Künstlern, Länder ohne Künstler und das ausgewählte Land sind auf den ersten Blick unterscheidbar.
- Falls Intensität Künstlerzahlen codiert, wird diese Bedeutung knapp und eindeutig erklärt; andernfalls wird keine scheinbare Skala suggeriert.
- Die Basiskarte unterstützt Orientierung, konkurriert aber nicht mit den Länderflächen.
- Markenfarbton wirkt in Light und Dark Mode sauber und besitzt ausreichenden Kontrast zu Wasser und Land.
- Auswahl, Zoom und Navigation zu einem Land bleiben unverändert.
- Prüfung umfasst Europa, weltweite Ansicht, Länder mit sehr kleinen Polygonen und beide Farbschemata.

