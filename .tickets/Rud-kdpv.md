---
id: Rud-kdpv
status: closed
deps: []
links: [Rud-e70l, Rud-tuxh]
created: 2026-07-11T03:11:28Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-sw5e
tags: [approved, design-audit, ios26, controls, voiceover, touch-targets, effort-small, confidence-high]
---
# Bewertungs- und Speicheraktionen als echte Controls umsetzen

ArtistRatingView und EventSavedIcon verwenden Images mit onTapGesture. Dadurch fehlen verlässliche Button-Semantik, Accessibility-Werte und teils 44-Punkt-Touch-Ziele.

## Design

Native Buttons einsetzen. Künstlerbewertung als klar benannte Auswahl oder Accessibility-adjustable Control repräsentieren. Zustand und Aktion im Accessibility-Label/Value ausdrücken.

## Acceptance Criteria

Alle Aktionen haben mindestens 44 x 44 Punkt; VoiceOver liest Zweck und aktuellen Zustand; Aktivierung funktioniert mit VoiceOver, Switch Control und Tastatur; visuelles Erscheinungsbild bleibt weitgehend unverändert.

## Notes

**2026-07-11T05:21:12Z**

Native Buttons, 44-Punkt-Trefferflächen sowie lokalisierte Accessibility-Labels, Werte und Selected-States für Künstlerbewertung und Event-Speichern umgesetzt. Auf iPhone 17e (iOS 26.5) gebaut, per Maestro in leerem und ausgewähltem Zustand geprüft und visuell per Screenshot kontrolliert.
