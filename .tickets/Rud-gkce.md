---
id: Rud-gkce
status: closed
deps: []
links: []
created: 2026-07-20T11:54:39Z
type: task
priority: 2
assignee: Leon Georgi
tags: [approved, ios26, artist-detail, design, accessibility]
---
# Künstlerdetail: Konzerte als offene Liste darstellen

## Notes

**2026-07-20T11:57:52Z**

Konzertbereich als offene Liste umgesetzt: äußere eventSurface-Karte und Innenpadding entfernt, Zeilen mit 10 pt vertikalem Rhythmus direkt auf dem Seitenhintergrund, eingerückte Separatoren nur zwischen mehreren Auftritten, Zeit-Badge beibehalten. Freundesindikator in die Metadatenzeile verschoben, sodass der Ortsname mehr Breite erhält; Bookmark, Chevron, Navigation, Konflikthinweise und Accessibility-Dynamic-Type-Verhalten bleiben erhalten. Unbenutzten eventSurface-Themewert entfernt. Verifiziert mit swiftc -parse der vier betroffenen Dateien, rg auf verbleibende eventSurface-Verwendungen und git diff --check. Kein Build oder Simulatorlauf in diesem Turn.
