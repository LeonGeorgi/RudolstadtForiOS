---
id: Rud-ure7
status: open
deps: []
links: [Rud-4lwc, Rud-m87x]
created: 2026-07-11T06:33:49Z
type: task
priority: 2
assignee: Leon Georgi
parent: Rud-4lwc
tags: [needs-approval, tests, accessibility, artists, map]
---
# Unit-Test für Accessibility-Repräsentation der Künstler-Weltkarte ergänzen

Die mit Rud-4lwc eingeführte Accessibility-Repräsentation der Künstler-Weltkarte ist noch nicht durch einen automatisierten Test abgesichert.

## Design

Die sortierte Länderreihenfolge, lokalisierte Künstlerzahl und Navigation der semantischen Länderaktionen auf testbare Logik zurückführen und deren beobachtbares Verhalten mit einem fokussierten Unit Test absichern.

## Acceptance Criteria

Ein Unit Test prüft mindestens alphabetische Länderreihenfolge, Künstlerzahl und die Zuordnung der ausgewählten Länderaktion zum korrekten Ländercode; der Test läuft im bestehenden Unit-Tests-Scheme.
