---
id: Rud-sa0w
status: open
deps: []
links: []
created: 2026-07-11T07:04:51Z
type: epic
priority: 1
assignee: Leon Georgi
tags: [needs-approval, tests, unit-tests, integration-tests, regression]
---
# Fachliche Testabdeckung für kritische App-Logik ausbauen

Die geschäftskritischen Verhaltensweisen der Festival-App mit deterministischen Unit-, Service- und Contract-Tests absichern, insbesondere Programmempfehlungen, Daten-Fallbacks, News und Festivalprofile.

## Design

Tests an beobachtbarem Verhalten und fachlichen Invarianten ausrichten. Reale Netzwerk-, CloudKit- und Notification-Systeme in der normalen Suite durch kontrollierte Adapter ersetzen; reale gebündelte JSON-Daten gezielt als Contract-Fixtures verwenden.

## Acceptance Criteria

Die priorisierten Risiko-Matrizen sind automatisiert abgedeckt; Fehlerfälle und Nebenläufigkeit sind berücksichtigt; alle Tests sind reproduzierbar und unabhängig von Uhrzeit, Sprache, Netzwerk und gemeinsamem UserDefaults-Zustand; die Child-Tickets dieses Epics sind abgeschlossen.
