---
id: Rud-ojw5
status: closed
deps: []
links: []
created: 2026-07-20T13:21:35Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved]
---
# Künstlerdetail: Scroll-Edge-Tönung über Full-Bleed-Hero entfernen

## Notes

**2026-07-20T13:25:45Z**

Ursache war der separate automatische Scroll Edge Effect von iOS 26. Im Full-Bleed-iPhone-Hero wird nun nur der obere Edge Effect über einen iOS-26-Availability-Modifier ausgeblendet; Toolbar-Hintergrundlogik und schwebende Buttons bleiben unverändert. Swift-Parse und git diff --check erfolgreich. Visuelle Bestätigung per Nutzerscreenshot ausstehend.

**2026-07-20T13:31:03Z**

Nach Nutzerpräzisierung dynamisch angepasst: Der obere Scroll Edge Effect ist nur verborgen, solange der große Künstlername im Inhalt sichtbar ist. Sobald dieser beim Scrollen verschwindet, wird der Effekt zusammen mit der Navigationbar wieder aktiv. Der Modifier bleibt strukturell stabil und aktualisiert nur den Bool-Wert, damit die Scrollposition erhalten bleibt. Swift-Parse und git diff --check erfolgreich.
