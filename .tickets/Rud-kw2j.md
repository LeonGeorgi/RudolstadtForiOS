---
id: Rud-kw2j
status: closed
deps: []
links: [Rud-ip2p]
created: 2026-07-11T03:11:27Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-dknv
tags: [approved, design-audit, ios26, permissions, notifications, effort-medium, confidence-high]
---
# Benachrichtigungsfreigabe kontextuell anfragen

RootTabView fordert die Notification-Berechtigung direkt bei onAppear an. Nutzer haben zu diesem Zeitpunkt den Nutzen der Festival-News noch nicht kennengelernt.

## Design

Berechtigung früh, aber zweistufig anfragen: Nach einer kurzen Orientierung im ersten Hauptscreen erscheint einmalig ein kompakter, app-eigener Hinweis mit Nutzen und bewusster Aktivierungsaktion. Erst diese Aktion öffnet den Systemdialog. Nach „Später“ bleibt die Aktivierung über die Einstellungen erreichbar.

## Acceptance Criteria

Kein Notification-Systemdialog erscheint allein durch den ersten App-Start; es gibt einen klaren Opt-in; Ablehnung blockiert keine App-Funktion; der Flow ist lokalisiert.

## Notes

**2026-07-11T06:54:35Z**

Vom Nutzer freigegeben. Umsetzung als früher zweistufiger Opt-in nach kurzer Orientierungsphase; Systemdialog nur nach bewusster Aktivierung, dauerhafter Einstieg in Einstellungen.

**2026-07-11T06:57:02Z**

Implementiert: einmaliger lokalisierter Pre-Prompt nach 5 Sekunden aktiver Nutzung, Systemdialog nur nach expliziter Aktivierung, persistentes Später, Notification-Status und Aktivierung in Einstellungen, Zustands-Unit-Test. Plutil- und Diff-Check erfolgreich; Build/Tests gemäß AGENTS.md nicht ausgeführt.
