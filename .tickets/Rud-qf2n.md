---
id: Rud-qf2n
status: closed
deps: []
links: [Rud-m370, Rud-tuxh]
created: 2026-07-11T03:11:27Z
type: task
priority: 1
assignee: Leon Georgi
parent: Rud-dknv
tags: [approved, design-audit, ios26, friends, onboarding, icloud, effort-medium, confidence-high]
---
# Freunde-Erstzustand als geführte Einrichtung gestalten

Im initialen Freunde-Screen erscheinen viele deaktivierte QR-, Share- und Scanner-Aktionen ohne eindeutige Erklärung, ob Name, iCloud oder Synchronisierung fehlt.

## Design

Die Einrichtung als kompakte, progressive Abfolge direkt im bestehenden Freunde-Screen gestalten, nicht als separaten Wizard:

1. Badge festlegen: Name und Farbe bearbeiten; ein nichtleerer normalisierter Name schließt den Schritt ab.
2. iCloud prüfen: Den Zustand „Wird geprüft“, „Bereit“ oder die konkrete Ursache der Nichtverfügbarkeit sichtbar und handlungsorientiert anzeigen.
3. Verbinden: Erst nach abgeschlossenem Badge und verfügbarem iCloud die Aktionen für QR-Code, Einladungslink und „Freund hinzufügen“ anbieten.

Bis die ersten beiden Schritte abgeschlossen sind, die leeren Folgeinhalte „Gemeinsam“, „Du folgst“ und „Folgt dir“ ausblenden. Die Privatsphäre-Erklärung beim Verbindungsschritt platzieren. Bestehende Nutzer mit Name und verfügbarem iCloud gelangen weiterhin direkt zum vollständigen Freunde-Screen.

Den Ablauf aus dem vorhandenen Profil- und iCloud-Zustand ableiten; keine zusätzliche persistierte Onboarding-Flag einführen. Deaktivierte Hauptaktionen nicht ohne Erklärung stehen lassen. Die visuelle und semantische Reihenfolge muss zugleich die VoiceOver-Reihenfolge des Setups bilden.

## Acceptance Criteria

Der Screen nennt immer den nächsten erforderlichen Schritt; jeder deaktivierte Hauptflow hat einen sichtbaren Grund oder eine Aktion; Empty-Bereiche werden vor Abschluss der Einrichtung reduziert; VoiceOver-Reihenfolge folgt dem Setup.

## Notes

**2026-07-11T08:24:07Z**

Freunde-Erstzustand aus Badge-Name und iCloud-Status abgeleitet: geführte Badge-/iCloud-Schritte, lokalisierte Statusursachen mit erneutem Prüfen, Verbindungsaktionen und Privatsphäre zusammengeführt, Folgeinhalte bis Setup-Abschluss verborgen. Verifiziert mit swiftc -parse, plutil -lint und git diff --check; kein Build/Simulatorlauf gemäß Projektvorgabe ohne explizite Freigabe.

**2026-07-11T08:35:09Z**

Optische Nachprüfung auf iPhone 17 Pro / iOS 26.4 mit XcodeBuildMCP und Maestro: Build nach Korrektur von Color.rudolstadt erfolgreich; englischer und deutscher Erstzustand sowie Übergang nach Badge-Speicherung geprüft. Texte vollständig sichtbar, Setup- und VoiceOver-Reihenfolge korrekt, Folgeabschnitte verborgen. Der vollständige Verbindungszustand ist im Screenshot-Modus nicht erreichbar, weil CloudKit dort absichtlich deaktiviert ist.
