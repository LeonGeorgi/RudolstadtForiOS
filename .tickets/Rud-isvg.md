---
id: Rud-isvg
status: open
deps: []
links: [Rud-ygcc, Rud-tuxh]
created: 2026-07-11T03:11:28Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-sw5e
tags: [needs-approval, design-audit, ios26, states, error-handling, localization, effort-medium, confidence-high]
---
# Loading-, Empty- und Error-States vereinheitlichen

Der globale FestivalDataGate ist verständlich, während Programm, News und Routing-Fallbacks teils rohe reason.rawValue-Texte, reine Farben oder fehlende Retry-Aktionen zeigen.

## Design

Eine fokussierte gemeinsame Zustandsdarstellung auf Basis von ContentUnavailableView verwenden: semantisches Symbol, lokalisierte Überschrift, Erklärung und passende Aktion.

## Acceptance Criteria

Programm und News haben verständliche Loading-, Empty- und Error-Zustände; technische rawValue-Texte sind nicht primärer Nutzertext; Netzwerkfehler bieten Retry; leere Suche bietet Filter- oder Suchreset; VoiceOver-Reihenfolge ist sinnvoll.

