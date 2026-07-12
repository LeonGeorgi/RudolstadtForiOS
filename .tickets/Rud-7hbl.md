---
id: Rud-7hbl
status: open
deps: [Rud-r2ax]
links: [Rud-tuxh]
created: 2026-07-11T04:21:05Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artist-detail, visual-design, social-links, effort-small, confidence-high]
---
# Künstlerdetail: Social- und Medienlinks als ruhige sekundäre Aktionsgruppe gestalten

Die runde Social-/Medienlink-Reihe ist verständlich und funktional, wirkt mit bis zu sechs 50-Punkte-Kreisen, 12 Punkten Abstand und relativ kontrastreichen Hintergründen jedoch wie eine zweite Toolbar direkt unter dem Header. Sie konkurriert dadurch mit Künstlername, Tags und Bewertung.

Betroffene Stelle:
- Shared/Screens/Artist/Detail/ArtistDetailHeaderView.swift, insbesondere ArtistDetailLinksView und LinkButton

Priorität: mittel
Aufwand: klein
Sicherheit: hoch

## Design

Die Linkreihe visuell zurücknehmen und als zusammengehörige sekundäre Aktionsebene behandeln:
- äußeren Durchmesser zunächst im Bereich 44 bis 46 Punkte prüfen
- Zwischenraum zunächst im Bereich 8 bis 10 Punkte prüfen
- Hintergrundkontrast über das zentrale Artist-Detail-Theme reduzieren
- unterschiedliche Symbolquellen optisch ausgleichen, sodass ihre wahrgenommenen Größen und Strichstärken zusammenpassen
- Gruppe mittig und mit eindeutigem Abstand zu Metadaten und Bewertung belassen
- bei wenigen Links keine künstliche Auffüllung oder asymmetrische Ausrichtung erzeugen

Die tatsächlichen Touch-Ziele dürfen durch die optische Verkleinerung nicht unter das idiomatische Mindestmaß fallen; bei Bedarf optische und interaktive Fläche trennen.

Nicht-Ziele:
- keine Glasbuttons für jede Plattform
- keine neue horizontale Scrollleiste
- keine Änderung der verfügbaren Links oder ihrer Ziele
- keine Zusammenfassung hinter einem zusätzlichen Menü, solange alle Links ohne Überfüllung passen

## Acceptance Criteria

- Reihen mit 1, 3 und 6 Links wirken jeweils bewusst komponiert und bleiben mittig.
- Die Links sind als sekundäre Aktionen erkennbar und überstrahlen weder Titel noch Bewertung.
- Alle interaktiven Flächen bleiben mindestens 44 mal 44 Punkte groß.
- Symbole verschiedener Anbieter wirken optisch ähnlich groß und vertikal ausgerichtet.
- Oberflächenfarben stammen aus dem gemeinsamen Artist-Detail-Theme.
- Darstellung wurde mit 5/8erl, A Birchola und Agnes Palmisano in Light und Dark Mode geprüft.

