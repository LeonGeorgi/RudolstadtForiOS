---
id: Rud-ip2p
status: open
deps: []
links: [Rud-kw2j]
created: 2026-07-11T07:20:11Z
type: task
priority: 2
assignee: Leon Georgi
tags: [needs-approval, notifications, testing, unit-tests]
---
# Notification-Opt-in mit Unit Tests absichern

Den neuen zweistufigen Notification-Opt-in aus Rud-kw2j über die bisherige reine Präsentationsentscheidung hinaus automatisiert absichern.

## Design

Die System-Notification-API hinter einer kleinen injizierbaren Schnittstelle kapseln und den Controller mit einem Fake testen. Zustandsübergänge für Aktivieren, Später, erteilte und abgelehnte Berechtigung sowie Fehler beim Anfordern prüfen. SwiftUI-Darstellung und der echte iOS-Systemdialog sind nicht Teil dieser Unit Tests.

## Acceptance Criteria

Unit Tests belegen: Nur eine explizite Aktivierung fordert die Systemberechtigung an; Später fordert sie nicht an und bleibt gespeichert; erlaubte und abgelehnte Zustände unterdrücken den Pre-Prompt; Statusänderungen werden übernommen; ein Fehler beim Anfordern lässt einen sicheren, erneut über die Einstellungen erreichbaren Zustand zurück.
