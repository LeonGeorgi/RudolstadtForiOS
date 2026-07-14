---
id: Rud-3wiy
status: closed
deps: []
links: []
created: 2026-07-11T03:11:28Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [approved, design-audit, ios26, artists, responsive-layout, dynamic-type, effort-medium, confidence-high]
---
# Künstler-Grid an Breite und Textgröße anpassen

Das immer dreispaltige Grid kürzt schon bei normaler Textgröße mehrere Künstlernamen. Kleine Geräte und große Texte verschärfen das Problem.

## Design

Adaptive Spaltenzahl verwenden: drei bei ausreichender Breite, zwei auf schmalen Geräten oder Accessibility-Größen. Namen mindestens zweizeilig zulassen. Fotozentrierte Gestaltung und Listenumschalter erhalten.

## Acceptance Criteria

Typische lange Namen sind auf iPhone 17e lesbar; AX-XXXL nutzt ein robustes Layout; Bildverhältnis und Übergangsanimation bleiben erhalten; Light und Dark Mode sind geprüft.

## Notes

**2026-07-12T16:57:19Z**

Gemeinsam mit Rud-ygcc umgesetzt: Darstellungsmenü bietet Liste, zwei und drei Spalten; Spaltenwahl wird in UserSettings gespeichert. Accessibility-Größen erzwingen weiterhin zwei Spalten, ohne die gespeicherte Wahl zu überschreiben. Visuell auf iPhone 17e / iOS 26.4 geprüft: Vorher /tmp/artist-grid-before.png und /tmp/artist-grid-before-dark.png; Menü /tmp/artist-grid-layout-menu-dark.png; zwei/drei Spalten /tmp/artist-grid-two-columns-dark.png und /tmp/artist-grid-three-columns-dark.png; Light /tmp/artist-grid-after-light.png; AX-XXXL /var/folders/5l/2600vsbn53zg45fssbbhv7ph0000gn/T/screenshot_optimized_4d3b82e5-8982-4a14-b9f8-789d7f4be654.jpg. Signierter Simulator-Build erfolgreich.
