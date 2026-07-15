---
id: Rud-2y23
status: closed
deps: [Rud-r2ax]
links: [Rud-tuxh]
created: 2026-07-11T04:21:04Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, artist-detail, visual-design, hero-image, effort-small, confidence-high]
---
# Künstlerdetail: Hero-Foto enger mit der fotoabgeleiteten Farbfläche verzahnen

Das Künstlerfoto ist hochwertig und bildet die Quelle der individuellen Seitenfarbe. Durch den aktuell großen horizontalen Einzug, die deutliche Kontur und den kräftigen schwarzen Schatten wirkt es jedoch wie eine separat aufgelegte Card. Das schwächt die Verbindung zwischen Motiv und umgebender Farbe.

Betroffene Stelle:
- Shared/Screens/Artist/Detail/ArtistDetailHeaderView.swift, insbesondere ArtistImageView mit horizontalem Padding, Kontur, Radius und Schatten

Im aktuellen Code liegen unter anderem 40 Punkte horizontaler Einzug, Radius 14 und ein schwarzer Schatten mit 25 Prozent Deckkraft, Radius 15 und y-Versatz 8 vor.

Priorität: mittel
Aufwand: klein
Sicherheit: hoch

## Design

Das Bild etwas großzügiger in der Breite zeigen und die Tiefenwirkung deutlich reduzieren. Als erste visuelle Arbeitswerte prüfen:
- horizontaler Einzug ungefähr 24 statt 40 Punkte
- Schatten ungefähr 10 bis 15 Prozent Deckkraft, Radius 7 bis 9, y-Versatz 3 bis 5
- bestehenden Bildradius um 14 Punkte und das Seitenverhältnis 8:7 zunächst beibehalten
- Kontur nur so stark lassen, wie sie für die Trennung bei ähnlicher Bild- und Hintergrundfarbe nötig ist

Die endgültigen Werte anhand mehrerer Motive festlegen, nicht anhand nur eines Screenshots.

Nicht-Ziele:
- kein Full-Bleed-Foto
- kein Gradient über dem Bild
- kein Liquid-Glass-Rahmen
- keine Änderung an Bildquelle, Zoom-Interaktion oder Seitenverhältnis ohne separaten Befund

## Acceptance Criteria

- Das Foto bleibt klar als Hero-Element erkennbar, wirkt aber weniger wie eine schwebende Card.
- Die fotoabgeleitete Hintergrundfarbe nimmt sichtbar Bezug zum Bild und wird nicht durch einen schweren Schatten getrennt.
- Helle Bildränder auf hellem Hintergrund und dunkle Bildränder auf dunklem Hintergrund bleiben ausreichend abgegrenzt.
- 5/8erl, A Birchola und Agnes Palmisano wurden in Light Mode geprüft; mindestens ein dunkles Motiv zusätzlich in Dark Mode.
- Bild-Zoom beziehungsweise vorhandene Tap-Interaktion bleibt unverändert funktionsfähig.
- Keine neuen dekorativen Materialien oder Effekte wurden hinzugefügt.

## Notes

**2026-07-14T02:08:20Z**

Hero-Foto bei normalen Textgrößen von 40 auf 24 Punkte horizontalen Einzug verbreitert; Schatten auf halbe Theme-Deckkraft, Radius 8 und y 4 reduziert. Build & Run auf iPhone 17e (iOS 26.5) erfolgreich. Vorher-/Iterations-Screenshots für 5/8erl, A Birchola und Agnes Palmisano in Light Mode sowie Agnes und 5/8erl in Dark Mode geprüft. Bild-Zoom geöffnet und wieder geschlossen; Interaktion unverändert funktionsfähig. Keine Tests ausgeführt, da ausschließlich visuelles Styling geändert wurde.
