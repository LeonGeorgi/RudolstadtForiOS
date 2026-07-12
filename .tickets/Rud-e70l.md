---
id: Rud-e70l
status: open
deps: []
links: [Rud-kdpv, Rud-tuxh]
created: 2026-07-11T04:21:05Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artist-detail, visual-design, rating, effort-small, confidence-high]
---
# Künstlerdetail: Bewertungszeile ohne unsichtbare Gegengewichte neu komponieren

Die Herzen werden aktuell in einem ZStack zentriert, während Reset links und ein weiteres Icon-Menü rechts als Overlay angeordnet sind. Mathematisch bleibt die Mitte erhalten, visuell entsteht jedoch eine unruhige und teilweise zufällige Dreiteilung. Besonders bei nicht verfügbarer Reset-Aktion wirken die unsichtbaren beziehungsweise wechselnden Seitengewichte wie ein Layout-Trick statt wie eine bewusste Aktionsgruppe.

Betroffene Stelle:
- Shared/Screens/Artist/Detail/ArtistRatingView.swift

Dieses Ticket behandelt ausschließlich Komposition und visuelle Hierarchie. Die bereits in Rud-kdpv erfasste Umstellung auf echte Controls und Accessibility-Semantik wird nicht dupliziert.

Priorität: mittel
Aufwand: klein
Sicherheit: hoch

## Design

Die sichtbaren Bewertungselemente als eine zusammenhängende, intrinsisch bemessene Gruppe komponieren:
- Herzbewertung und zugehörige Menüaktion räumlich eindeutig verbinden
- die Gruppe als Ganzes zentrieren, statt ihre Mitte durch unsichtbare Gegenflächen zu erzwingen
- Reset nur zeigen, wenn er semantisch relevant ist; dann als klar nachgeordnete Aktion in unmittelbarer Beziehung zur Bewertung
- keine leeren Platzhalter zur Symmetrie verwenden
- Abstände und Symbolgewichte so wählen, dass die Herzreihe der klare Fokus bleibt

Nicht-Ziele:
- keine Änderung des Bewertungsmodells
- keine neue Bewertungsanimation
- keine Duplizierung der Control- und VoiceOver-Arbeit aus Rud-kdpv
- keine dekorative Card um die Bewertungszeile

## Acceptance Criteria

- Die Bewertung wirkt bei leerem, teilweisem und vollständigem Rating ausgewogen.
- Ein- und ausgeblendete Reset-Aktionen verursachen keine scheinbar zufällige Verschiebung oder leere Gegenfläche.
- Herzreihe und Menü werden als eine zusammengehörige Funktion verstanden, die Herzreihe bleibt visuell dominant.
- Mit und ohne vorhandene Bewertung sowie bei größeren Textgrößen entstehen keine Überlagerungen.
- Die spätere beziehungsweise parallele Umsetzung von Rud-kdpv bleibt ohne erneuten Layoutumbau möglich.
- Das Ergebnis wurde auf kleinem und großem iPhone in Light und Dark Mode geprüft.

