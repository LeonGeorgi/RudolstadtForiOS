---
id: Rud-33yh
status: closed
deps: []
links: [Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, artists, visual-design, toolbar, world-map-entry, effort-small, confidence-high]
---
# Künstlerübersicht: Suche, Weltkarten-Einstieg und Toolbar klar gewichten

Am oberen Rand der Künstlerübersicht stehen die native Suchdarstellung, mehrere Toolbar-Aktionen und ein großer kapselartiger Weltkarten-Einstieg dicht hintereinander. Jedes Element ist funktional sinnvoll, zusammen entsteht jedoch ein schwerer Kontrollblock, der den eigentlichen Fotoinhalt nach unten drückt. Der Weltkarten-Einstieg sieht durch Capsule, Akzentfarbe und Metatext fast wie eine zusätzliche Systemsteuerung aus, obwohl er ein inhaltlicher Discovery-Einstieg ist.

Betroffene Stellen:
- Shared/Screens/Artist/Overview/ArtistBrowseView.swift
- Shared/Screens/Artist/Overview/ArtistListToolbar.swift
- Shared/Screens/Artist/Overview/ArtistOverviewGridView.swift
- Shared/Screens/Artist/Overview/ArtistOverviewListView.swift
- Shared/Screens/Artist/Overview/ArtistWorldMapCalloutCard.swift

Priorität: mittel
Aufwand: klein
Sicherheit: hoch

## Design

Die Ebenen nach ihrer Rolle ordnen:
- native Suche als primäre temporäre Filterinteraktion unverändert systemnah belassen
- Toolbar auf häufige globale Ansichts-/Filteraktionen begrenzen und visuell gleichwertige Icons konsistent dimensionieren
- Weltkarten-Einstieg klar als Content-Discovery und nicht als weitere Toolbar darstellen, beispielsweise als kompakte Inhaltszeile mit Globe, Titel und nachgeordnetem Hinweis
- Capsule und flächige Akzentfarbe reduzieren, wenn sie den Einstieg wie einen schwebenden iOS-26-Control erscheinen lassen
- vertikalen Abstand so setzen, dass Weltkarten-Einstieg und erstes Grid-Element als zusammengehöriger Content-Flow gelesen werden
- Einstieg in Grid- und Listenmodus konsistent behandeln

Liquid Glass nur für echte System-/Navigationscontrols verwenden; der Karten-Einstieg benötigt keine eigene Glasfläche.

Nicht-Ziele:
- keine Entfernung der Weltkarte
- keine Verlagerung der Suche in ein eigenes Screen
- keine neue Filterlogik
- keine zusätzliche Hero-Card über dem Grid

## Acceptance Criteria

- Der erste Blick fällt auf Künstlerbilder beziehungsweise Suchergebnisse, nicht auf einen Stapel von Controls.
- Suche, Toolbar und Weltkarten-Einstieg sind anhand ihrer Gestaltung eindeutig als unterschiedliche Rollen erkennbar.
- Der Weltkarten-Einstieg bleibt auffindbar, hat ein Touch-Ziel von mindestens 44 Punkten Höhe und funktioniert in Grid- und Listenmodus.
- Toolbar-Symbole besitzen konsistente optische Größen und Abstände.
- Light und Dark Mode sowie leerer, aktiver und langer Suchtext wurden geprüft.
- Die bestehende Weltkarten-Discovery bleibt entsprechend Rud-tuxh erhalten.

## Notes

**2026-07-12T16:17:38Z**

Weltkarten-Einstieg als ruhige, linksbündige Discovery-Zeile ohne Capsule umgesetzt; Grid- und Listenabstände angeglichen. Verifiziert auf iPhone 17 / iOS 26.4 in Grid und Liste, Light und Dark Mode, mit aktivem langem Suchtext/leerem Ergebnis sowie durch Antippen und Navigation zur Weltkarte. Simulator-Build erfolgreich.
