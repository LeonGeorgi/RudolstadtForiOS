---
id: Rud-88vy
status: closed
deps: []
links: []
created: 2026-07-21T05:42:41Z
type: task
priority: 1
assignee: Leon Georgi
tags: [approved, apple-music, artist-detail]
---
# Kuratierte Apple-Music-Previews auswählen

Alle 2026-Künstler mit Apple-Music-Verknüpfung prüfen und bei unrepräsentativer automatischer Preview einen konkreten Song-Override hinterlegen.

## Design

Apple-Music-Profillink und Preview-Song getrennt modellieren. Kuratierte Song-ID gewinnt; ohne Override bleibt ein sicherer, exakt zur Artist-ID passender Fallback. Keine Titelheuristik.

## Acceptance Criteria

Jeder verknüpfte Künstler wurde geprüft; nur begründete Overrides sind eingetragen; Alex Boldin spielt eine repräsentative Fingerstyle-Gitarren-Preview; Parser und Auswahl sind getestet; bestehende Profillinks bleiben unverändert.

## Notes

**2026-07-21T06:18:26Z**

Audit abgeschlossen: 104 ursprüngliche Apple-Music-Verknüpfungen geprüft. 30 repräsentative Song-Overrides hinterlegt (inkl. Alex Boldin – Fingerstyle Blues), 71 AUTO-Fälle mit exakter Artist-/Collection-ID und verfügbarer Preview validiert, 3 nachweislich falsche Profile entfernt (Balafenn, between the trees and me, ZOFF). Alle Override-Namen lösen exakt auf; keine Duplikate, Kollisionen oder verwaisten Einträge. Parser/Resolver decken curated, automatic, disabled und ungültige Nicht-Song-Overrides ab. Verifiziert mit aktuellen Lookup-Antworten, Swift-Parse, fokussiertem Module-Compile, PBX-Lint und diff-check; kein Xcode-/Simulator-Build ausgeführt.
