---
id: Rud-zjry
status: closed
deps: []
links: []
created: 2026-07-20T12:07:27Z
type: task
priority: 2
assignee: Leon Georgi
tags: [approved, ios26, artist-detail, design, accessibility]
---
# Künstlerdetail: Konzertliste vertikal verdichten

## Notes

**2026-07-20T12:08:31Z**

Konzertliste auf der Künstlerdetailseite verdichtet: Zeit-Badge regulär 48 statt 52 pt, Zeilenpadding regulär 4 statt 10 pt, Abstand Bewertung→Konzerte 12 statt 16 pt und Konzerte→Links 12 statt 20 pt. Ohne Konzerte bleibt der bisherige Link-Abstand erhalten. Accessibility behält 52-pt-Badge, 10-pt-Zeilenpadding und großzügige Außenabstände. EventTimeBadge über optionalen size-Parameter scoped wiederverwendbar; andere Screens nutzen weiterhin Standard 52. Verifiziert mit swiftc -parse der vier betroffenen Dateien, Aufrufer-Suche und git diff --check. Kein Build/Simulatorlauf.
