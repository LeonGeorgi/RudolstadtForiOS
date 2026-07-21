---
id: Rud-2p87
status: closed
deps: []
links: []
created: 2026-07-20T11:42:25Z
type: task
priority: 2
assignee: Leon Georgi
tags: [approved, ios26, artist-detail, design, accessibility]
---
# Künstlerdetail: Bewertung als klar bedienbares Kompakt-Control

## Notes

**2026-07-20T11:45:32Z**

Bewertungsleiste als zusammenhängendes 48-pt-Kompakt-Control gestaltet: sichtbare actionSurface-Pille mit feiner Kontur, weiterhin 44x44 pt pro Aktion, Herzen auf 29 pt vergrößert, Reset/Palettenaktion optisch angeglichen und Palette durch einen feinen Trenner gruppiert. Keine quadratischen Auswahlflächen; Freundesindikator bleibt direkt daneben. Verifiziert mit swiftc -parse und git diff --check; kein Build/Simulatorlauf in diesem Turn.
