---
id: Rud-fo95
status: open
deps: [Rud-e1lc]
links: []
created: 2026-07-11T07:04:52Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-sa0w
tags: [needs-approval, tests, news, notifications, cache, localization, effort-medium, confidence-high]
---
# News-Cache, Benachrichtigungen und Fehlerpfade vollständig testen

Die vorhandenen NewsService-Tests zu einer vollständigen Matrix für Cache, Download, Bundle-Fallback, Lesestatus und lokale Benachrichtigungen ausbauen.

## Design

Kontrollierte Fetch-, Cache- und Notifier-Stubs verwenden. Frische, veraltete, fehlende und unlesbare Daten sowie Speicherfehler abdecken; Sprachfilter und Deduplizierung separat parametrisieren.

## Acceptance Criteria

Netzwerk- und Speicherfehler haben für jeden Cache-Zustand getestetes Verhalten; neue Meldungen werden nur einmal und nur in der aktuellen Sprache benachrichtigt; oldNews und readNews werden korrekt aktualisiert; Notification-Payload-Navigation ist abgesichert.
