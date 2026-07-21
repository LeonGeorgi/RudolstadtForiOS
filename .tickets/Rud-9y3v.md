---
id: Rud-9y3v
status: closed
deps: []
links: []
created: 2026-07-20T13:50:17Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved]
---
# Künstlerdetail: Größerer Hero-Titel und neutrales Theme

## Notes

**2026-07-20T13:54:32Z**

Implementiert: Hero-Overlay-Titel von .title.bold() auf .largeTitle.bold() erhöht. Künstlerabgeleitetes Detail-Theme vollständig deaktiviert und synchron durch ArtistDetailTheme.fallback(for: systemColorScheme) ersetzt, sodass Seite, Aktionsflächen, Inhaltskarten, Trenner und Bildrahmen gemeinsam neutral sind. Async-Theme-Ladelogik aus ArtistDetailView entfernt; Color-Cache für möglichen späteren Vergleich unverändert belassen. Swift-Parse und git diff --check erfolgreich; visueller Screenshot-Check ausstehend.
