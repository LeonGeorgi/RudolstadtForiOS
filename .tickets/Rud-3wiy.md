---
id: Rud-3wiy
status: open
deps: []
links: []
created: 2026-07-11T03:11:28Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-lyze
tags: [needs-approval, design-audit, ios26, artists, responsive-layout, dynamic-type, effort-medium, confidence-high]
---
# Künstler-Grid an Breite und Textgröße anpassen

Das immer dreispaltige Grid kürzt schon bei normaler Textgröße mehrere Künstlernamen. Kleine Geräte und große Texte verschärfen das Problem.

## Design

Adaptive Spaltenzahl verwenden: drei bei ausreichender Breite, zwei auf schmalen Geräten oder Accessibility-Größen. Namen mindestens zweizeilig zulassen. Fotozentrierte Gestaltung und Listenumschalter erhalten.

## Acceptance Criteria

Typische lange Namen sind auf iPhone 17e lesbar; AX-XXXL nutzt ein robustes Layout; Bildverhältnis und Übergangsanimation bleiben erhalten; Light und Dark Mode sind geprüft.

