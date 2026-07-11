---
id: Rud-ip2p
status: open
deps: []
links: [Rud-kw2j]
created: 2026-07-11T07:20:11Z
type: task
priority: 2
assignee: Leon Georgi
tags: [needs-approval, notifications, testing, ios26]
---
# Notification-Opt-in im Simulator testen

Den neuen zweistufigen Notification-Opt-in aus Rud-kw2j auf einer frischen Installation im iOS-26-Simulator funktional und visuell prüfen.

## Design

Frische Installation sowie die Pfade Aktivieren, Später, Ablehnen und Rückkehr aus den Systemeinstellungen prüfen. Zusätzlich Deutsch/Englisch, Dynamic Type und VoiceOver berücksichtigen.

## Acceptance Criteria

Der Pre-Prompt erscheint erst nach der Orientierungsphase; der Systemdialog nur nach expliziter Aktivierung; Später bleibt respektiert; der Einstellungsstatus aktualisiert sich korrekt; Layout und Bedienung sind auf kleiner und großer Gerätegröße geprüft.
