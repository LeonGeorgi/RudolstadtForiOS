---
id: Rud-78om
status: open
deps: []
links: []
created: 2026-07-11T03:11:29Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-7rmh
tags: [needs-approval, design-audit, ios26, localization, semantic-colors, typography, effort-small, confidence-high]
---
# Harte UI-Strings und nichtsemantische Styles bereinigen

Mehrere sichtbare oder vorgelesene Texte sind hart auf Englisch codiert, etwa Center on festival area, On/Off, Close map, Locate me, No rating und Failed to load. Einzelne Zustände verwenden pauschal gray/red oder feste Schriftgrößen.

## Design

Alle Nutzer- und Accessibility-Texte lokalisieren; semantische foregroundStyle-Werte und Systemtypografie nutzen; Rot nur für echte Fehler oder die aktuelle Zeit einsetzen.

## Acceptance Criteria

Keine identifizierten harten englischen Texte bleiben in den betroffenen Screens; Deutsch und Englisch sind vollständig; Light/Dark Mode und VoiceOver-Werte sind geprüft; feste Schrift in MoreView ist entfernt.

