---
id: Rud-ygcc
status: closed
deps: [Rud-3wiy]
links: [Rud-isvg, Rud-tuxh]
created: 2026-07-11T04:25:57Z
type: task
priority: 3
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, artists, visual-design, grid, typography, loading, effort-small, confidence-high]
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

## Notes

**2026-07-12T16:57:19Z**

Gemeinsam mit Rud-3wiy umgesetzt: Namen nutzen bei normalen Größen bis zu zwei Zeilen und eine stabile Metadatenhöhe; bei Accessibility-Größen vollständiger Umbruch mit auf AX-XXL begrenzter Zellentypografie. Länder werden aus Country-Codes lokalisiert und ohne Emoji-Baseline-Sprünge dargestellt; fehlende Codes fallen sicher auf bereinigten Rohtext zurück. Grid-Ladezustand ist ohne dominanten Spinner ruhig, andere ArtistImageView-Kontexte bleiben unverändert. Light/Dark, kurze/lange Namen und Zwei-/Drei-Spalten-Layout visuell geprüft. Gezielter Persistenztest Unit Tests/UserPreferencesStoreTests/persistsArtistGridColumnCount erfolgreich; git diff --check sauber. Separater AX-Befund am Weltkarten-Callout als Rud-cu1x mit needs-approval erfasst.

**2026-07-13T00:30:14Z**

Nach Nutzerfeedback wieder geöffnet: Das Ergebnis soll systemnäher und stärker wie eine von Apple gestaltete Browse-Ansicht wirken. Fokus der Nachbesserung: Zellrhythmus, typografische Hierarchie, Abstände und Symbolhierarchie des Darstellungsmenüs; bestehende Spaltenwahl und Bildsprache bleiben erhalten.

**2026-07-13T00:44:42Z**

Design-Nachbesserung nach Nutzerfeedback abgeschlossen. In mehreren Screenshot-Iterationen wurden künstliche Metadaten-Mindesthöhen und Bildkonturen entfernt, Ecken auf 12 pt beruhigt, Bild-/Textabstand auf 7 pt und Rasterzeilenabstand auf 18 pt abgestimmt sowie die Länderzeile auf systemnahes Footnote/secondary umgestellt. Das Darstellungsmenü nutzt nun einen nativen Inline-Picker mit SF-Symbolen und System-Checkmark für Liste, zwei und drei Spalten. Visuell geprüft auf iPhone 17e/iOS 26.4: Light Mode in beiden Dichten, Dark Mode in beiden Dichten und Menü sowie AX-XXXL. Finale Screenshots: /tmp/artist-grid-two-columns-dark.png, /tmp/artist-grid-three-columns-dark.png, /tmp/artist-grid-layout-menu-dark.png und /var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_3a02cc0b-284f-4409-8f05-ffe1a400363a.jpg. Simulator auf Light Mode/large zurückgestellt; Build erfolgreich; git diff --check sauber.
