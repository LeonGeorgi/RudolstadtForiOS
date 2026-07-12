---
id: Rud-ygcc
status: open
deps: [Rud-3wiy]
links: [Rud-isvg, Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 3
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artists, visual-design, grid, typography, loading, effort-small, confidence-high]
---
# Künstler-Grid: Typografie, Länderzeile und Ladebild harmonisieren

Das fotozentrierte Künstler-Grid ist grundsätzlich gelungen. Unter den Bildern schwankt die optische Dichte jedoch stark: kurze und lange Namen erzeugen unterschiedliche Rhythmen, Ländertexte und direkt angehängte Emoji-Flaggen besitzen eine andere Grundlinie und Bildsprache als die SF-Symbol-basierte Oberfläche. Während Bilder laden, sind die Platzhalter visuell relativ präsent und lassen das Raster unfertiger wirken als nötig.

Betroffene Stellen:
- Shared/Screens/Artist/Overview/ArtistGridCell.swift
- Shared/Screens/Artist/Overview/ArtistOverviewGridView.swift
- Shared/Screens/Artist/Components/ArtistImageView.swift

Die adaptive Spaltenzahl und Zeilenbreite werden in Rud-3wiy gelöst. Allgemeine Loading-/Error-Logik bleibt in Rud-isvg.

Priorität: niedrig
Aufwand: klein
Sicherheit: hoch

## Design

Nach Festlegung der adaptiven Gridbreite den Zellrhythmus verfeinern:
- Künstlernamen über eine konsistente Zeilenreserve beziehungsweise Ausrichtung stabilisieren, ohne kurze Namen künstlich weit vom Bild zu trennen
- Abstand zwischen Bild, Name und Länderzeile als wiederverwendbare Zellmetriken definieren
- Länderinformation vereinfachen; Emoji-Flaggen nur behalten, wenn sie vollständig, korrekt und optisch konsistent verfügbar sind, andernfalls den lokalisierten Ländernamen allein bevorzugen
- Länderzeile klar sekundär halten und auf lange Kombinationen testen
- Bild-Platzhalter farblich näher an systemFill beziehungsweise den umgebenden Hintergrund führen und ohne unnötigen Rahmen oder dominantes Symbol gestalten
- Favoriten-/Statussymbole auf dem Bild als kleine funktionale Overlays erhalten

Nicht-Ziele:
- keine generische Card um jede Künstlerzelle
- keine Entfernung der Künstlerfotos
- keine Änderung der Bild-Navigationstransition
- keine Duplizierung der responsiven Gridarbeit aus Rud-3wiy

## Acceptance Criteria

- Gridzeilen wirken auch bei gemischten ein- und zweizeiligen Namen ruhig ausgerichtet.
- Länderzeilen sind typografisch konsistent und erzeugen keine zufälligen Flaggen-/Text-Baseline-Sprünge.
- Fehlende oder mehrdeutige Flaggen hinterlassen keine leeren oder fehlerhaften Metadatenfragmente.
- Ladeplatzhalter treten hinter bereits geladenen Künstlerbildern zurück und verursachen keinen Layoutsprung.
- Prüfung umfasst kurze und lange Namen, ein und mehrere Länder, fehlende Länderinformation sowie teilweise geladene Bilder.
- Rud-3wiy und Rud-isvg können ohne widersprüchliche Änderungen umgesetzt werden.

